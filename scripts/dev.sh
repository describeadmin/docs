#!/usr/bin/env bash
#
# 一条命令拉起/销毁【当前 worktree 专属】的开发环境或测试环境
# （develop_plan.md 6.1「命名空间隔离策略」/ 6.2「开发者体验封装」）。
#
# ---------------------------------------------------------------------------
# 背景：本项目是多仓拓扑（3.1.1），一个「逻辑 worktree」实际上是工作区根目录
# （本文件所在 docs/ 的上一级）下并列的多个 git 仓库
# （framework / sample-app / frontend / sample-frontend / ...）各自切到同一
# 功能分支各开一份 `git worktree add`。因此 slug 不从某个仓库的分支名/
# worktree 元数据反推——那在多仓下没有单一权威来源——而是直接对
# 【工作区根目录的绝对路径】取 hash：同一个工作区根目录天然对应同一个逻辑
# worktree，与里面哪个仓库当前切到哪个分支无关。
#
# 隔离模型分两层，对应 6.1 明确的取舍：
#   dev  —— 数据库/Redis 用【共享的常驻实例】，按 worktree 分 schema / db index；
#           应用进程（sample-app 后端 + sample-frontend 前端）按 worktree
#           走【独立进程 + 独立端口】，保证代码热更新互不干扰。
#   test —— 直接复用 docker-compose.test.yml（5.1/5.6）。该文件的模型本来就是
#           「每次测试一套独立容器、tmpfs、一次性重建」，本脚本只负责把 slug
#           算出的 COMPOSE_PROJECT_NAME / 端口喂给它，避免多个 worktree 同时
#           跑测试时互相抢容器名或端口。
#
# 用法：
#   ./scripts/dev.sh slug                打印当前工作区的 slug 与全部派生参数
#   ./scripts/dev.sh dev up              拉起共享 MySQL/Redis（幂等）
#                                         + 建本 worktree 专属 schema
#                                         + 后台起 sample-app 与 sample-frontend
#   ./scripts/dev.sh dev status          查看本 worktree 开发环境的进程/端口
#   ./scripts/dev.sh dev logs back|front 跟踪对应进程日志（Ctrl+C 退出不影响进程本身）
#   ./scripts/dev.sh dev down            停止【本 worktree 的】应用进程；
#                                         不动共享的 da-mysql/da-redis 容器——
#                                         其他 worktree 可能还在用
#   ./scripts/dev.sh test up             起本 worktree 专属的测试环境容器
#   ./scripts/dev.sh test down           down -v，不留残留卷
#   ./scripts/dev.sh test status
#
# 可覆盖的环境变量（均有默认值，与 sample-app/README、application-local.yml
# 注释里已经手工使用的约定保持一致，不引入新的隐性约定）：
#   DEV_MYSQL_PORT      共享 dev MySQL 的宿主机端口，默认 3307
#   DEV_MYSQL_ROOT_PASSWORD  默认 root
#   DEV_APP_DB_USER / DEV_APP_DB_PASSWORD   默认 app / app
#
# ⚠️ 已知限制（如实记录，不隐藏）：
#   - `dev down` 依赖脚本自己写的 pid 文件杀进程；mvn/pnpm 在 Windows 上会派生
#     真正的 java/node 子进程，本脚本用 taskkill /T 尽量把进程树一起杀掉，
#     但如果子进程被系统重新收养（极端情况），可能需要手动 `docker ps`/
#     任务管理器确认端口已释放。
#   - 共享的 da-mysql 里的 `app` 用户默认只被 MYSQL_DATABASE（`describeadmin`）
#     授权（官方镜像行为），本脚本首次建共享容器时会显式再 GRANT 一次，
#     否则新建的 worktree schema 对 `app` 用户不可见，表现为登录时报
#     "Access denied"，而不是更直观的"库不存在"。
# ---------------------------------------------------------------------------

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
WORKSPACE_DIR="$(cd "$DOCS_DIR/.." && pwd)"

DEV_MYSQL_PORT="${DEV_MYSQL_PORT:-3307}"
DEV_MYSQL_ROOT_PASSWORD="${DEV_MYSQL_ROOT_PASSWORD:-root}"
DEV_APP_DB_USER="${DEV_APP_DB_USER:-app}"
DEV_APP_DB_PASSWORD="${DEV_APP_DB_PASSWORD:-app}"

# ---------------------------------------------------------------------------
# slug 与派生参数
# ---------------------------------------------------------------------------

hash_of() {
  # 优先 sha1sum（git bash / linux 都有），没有则退化到 shasum（macOS）。
  # 只取前 8 位十六进制，够用且短，不追求防碰撞强度。
  if command -v sha1sum >/dev/null 2>&1; then
    printf '%s' "$1" | sha1sum | cut -c1-8
  else
    printf '%s' "$1" | shasum | cut -c1-8
  fi
}

SLUG="$(hash_of "$WORKSPACE_DIR")"

# 端口偏移：取 slug 前 4 位十六进制转十进制，对 100 取模再乘 5，
# 得到 0~495、步长 5 的偏移量——足够把常见的几组端口错开，
# 又不会把端口号推到离默认值太远、不好记的范围。
OFFSET=$(( (16#${SLUG:0:4} % 100) * 5 ))
# Redis db index 只有 0~15，用 slug 另外两位十六进制取模，
# 与端口偏移用不同的位段，避免两者按同一种方式碰撞。
DEV_REDIS_DB=$(( 16#${SLUG:4:2} % 16 ))

BACKEND_PORT=$((8090 + OFFSET))
FRONTEND_PORT=$((5777 + OFFSET))
MYSQL_TEST_PORT=$((13306 + OFFSET))
REDIS_TEST_PORT=$((16379 + OFFSET))
DEV_SCHEMA="describeadmin_${SLUG}"
TEST_PROJECT_NAME="describeadmin-test-${SLUG}"

STATE_DIR="$DOCS_DIR/.worktree/$SLUG"
mkdir -p "$STATE_DIR"

print_params() {
  cat <<EOF
工作区    : $WORKSPACE_DIR
slug      : $SLUG
--- dev（共享实例 + 独立进程）---
后端端口  : $BACKEND_PORT   (SERVER_PORT)
前端端口  : $FRONTEND_PORT  (vite --port)
DB schema : $DEV_SCHEMA     (共享 da-mysql:$DEV_MYSQL_PORT)
Redis db  : $DEV_REDIS_DB   (共享 da-redis，0~15)
状态目录  : $STATE_DIR
--- test（每 worktree 独立容器）---
项目名    : $TEST_PROJECT_NAME
MySQL 端口: $MYSQL_TEST_PORT
Redis 端口: $REDIS_TEST_PORT
EOF
}

# ---------------------------------------------------------------------------
# 工具函数
# ---------------------------------------------------------------------------

is_windows() {
  case "${OS:-}${OSTYPE:-}" in
    *Windows_NT*|*msys*|*cygwin*|*MINGW*) return 0 ;;
    *) return 1 ;;
  esac
}

# 杀掉 pid 文件记录的进程（及其进程树）。找不到 pid 文件或进程已退出都不算错误。
kill_pid_file() {
  local file="$1" pid
  [[ -f "$file" ]] || return 0
  pid="$(cat "$file")"
  [[ -n "$pid" ]] || { rm -f "$file"; return 0; }
  if is_windows; then
    taskkill //F //T //PID "$pid" >/dev/null 2>&1 || true
  else
    kill -TERM "$pid" >/dev/null 2>&1 || true
    sleep 1
    kill -KILL "$pid" >/dev/null 2>&1 || true
  fi
  rm -f "$file"
}

pid_alive() {
  local file="$1" pid
  [[ -f "$file" ]] || return 1
  pid="$(cat "$file")"
  [[ -n "$pid" ]] || return 1
  if is_windows; then
    tasklist //FI "PID eq $pid" 2>/dev/null | grep -q "$pid"
  else
    kill -0 "$pid" >/dev/null 2>&1
  fi
}

mysql_exec() {
  # 在共享的 da-mysql 容器里执行一条 SQL；--default-character-set 显式指定，
  # 遵循 CLAUDE.md 3.6（虽然这里没有读外部文件，但保持同一条纪律，不留例外）。
  docker exec -i da-mysql \
    mysql -uroot -p"$DEV_MYSQL_ROOT_PASSWORD" --default-character-set=utf8mb4 -e "$1"
}

# ---------------------------------------------------------------------------
# dev 子命令
# ---------------------------------------------------------------------------

ensure_dev_mysql() {
  if docker inspect -f '{{.State.Running}}' da-mysql >/dev/null 2>&1; then
    [[ "$(docker inspect -f '{{.State.Running}}' da-mysql)" == "true" ]] || docker start da-mysql >/dev/null
  else
    echo "▸ 首次运行，创建共享 da-mysql 容器（端口 $DEV_MYSQL_PORT）"
    docker run -d --name da-mysql -p "${DEV_MYSQL_PORT}:3306" \
      -e MYSQL_ROOT_PASSWORD="$DEV_MYSQL_ROOT_PASSWORD" \
      -e MYSQL_DATABASE=describeadmin \
      -e MYSQL_USER="$DEV_APP_DB_USER" -e MYSQL_PASSWORD="$DEV_APP_DB_PASSWORD" \
      mysql:5.7 --character-set-server=utf8mb4 --collation-server=utf8mb4_general_ci >/dev/null
  fi

  echo "▸ 等待 da-mysql 就绪..."
  local tries=0
  until docker exec da-mysql mysqladmin ping -h127.0.0.1 -uroot -p"$DEV_MYSQL_ROOT_PASSWORD" --silent >/dev/null 2>&1; do
    tries=$((tries + 1))
    [[ $tries -gt 30 ]] && { echo "✗ da-mysql 30 秒内未就绪" >&2; exit 1; }
    sleep 1
  done

  echo "▸ 建本 worktree 专属 schema：$DEV_SCHEMA"
  # app 用户默认只被官方镜像授权访问 MYSQL_DATABASE（describeadmin）这一个库，
  # 新建的 worktree 专属 schema 必须显式 GRANT，否则登录时报 Access denied，
  # 且报错信息完全不会提示"schema 没被授权"这个真实原因。
  mysql_exec "CREATE DATABASE IF NOT EXISTS \`$DEV_SCHEMA\` CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
              GRANT ALL PRIVILEGES ON \`$DEV_SCHEMA\`.* TO '$DEV_APP_DB_USER'@'%';
              FLUSH PRIVILEGES;"
}

ensure_dev_redis() {
  if docker inspect -f '{{.State.Running}}' da-redis >/dev/null 2>&1; then
    [[ "$(docker inspect -f '{{.State.Running}}' da-redis)" == "true" ]] || docker start da-redis >/dev/null
  else
    echo "▸ 首次运行，创建共享 da-redis 容器（默认端口 6379，仅容器间/本机可达）"
    docker run -d --name da-redis -p 6379:6379 redis:7-alpine >/dev/null
  fi
}

dev_up() {
  ensure_dev_mysql
  # Redis 目前不是 sample-app 默认 profile 的必需依赖（只有装了
  # framework-cache-redis-starter 才用得到），起失败不阻塞主流程，只提示。
  ensure_dev_redis || echo "⚠ da-redis 未能启动，跳过（不影响未启用该插件的默认 profile）"

  local ds_url="jdbc:mysql://localhost:${DEV_MYSQL_PORT}/${DEV_SCHEMA}?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=Asia/Shanghai&characterEncoding=utf8"

  echo "▸ 后台启动 sample-app（端口 $BACKEND_PORT，日志见 $STATE_DIR/backend.log）"
  (
    cd "$WORKSPACE_DIR/sample-app"
    SERVER_PORT="$BACKEND_PORT" \
    SPRING_DATASOURCE_URL="$ds_url" \
    SPRING_DATASOURCE_USERNAME="$DEV_APP_DB_USER" \
    SPRING_DATASOURCE_PASSWORD="$DEV_APP_DB_PASSWORD" \
    SPRING_DATA_REDIS_DATABASE="$DEV_REDIS_DB" \
    nohup mvn spring-boot:run -Dspring-boot.run.profiles=local \
      > "$STATE_DIR/backend.log" 2>&1 &
    echo $! > "$STATE_DIR/backend.pid"
  )

  echo "▸ 后台启动 sample-frontend（端口 $FRONTEND_PORT，日志见 $STATE_DIR/frontend.log）"
  (
    cd "$WORKSPACE_DIR/sample-frontend"
    VITE_PROXY_TARGET="http://localhost:${BACKEND_PORT}" \
    nohup pnpm run dev -- --port "$FRONTEND_PORT" --strictPort \
      > "$STATE_DIR/frontend.log" 2>&1 &
    echo $! > "$STATE_DIR/frontend.pid"
  )

  echo
  echo "✔ 已拉起本 worktree（$SLUG）专属开发环境"
  print_params
  echo
  echo "首次启动 sample-app 需要跑一遍建表+种子（几秒到几十秒），"
  echo "用 './scripts/dev.sh dev logs back' 看进度；前端就绪后访问 http://localhost:$FRONTEND_PORT"
}

dev_down() {
  echo "▸ 停止本 worktree 的应用进程（不动共享的 da-mysql/da-redis 容器）"
  kill_pid_file "$STATE_DIR/backend.pid"
  kill_pid_file "$STATE_DIR/frontend.pid"
  echo "✔ 完成。本 worktree 专属 schema（$DEV_SCHEMA）未删除——如需彻底清理："
  echo "  docker exec da-mysql mysql -uroot -p$DEV_MYSQL_ROOT_PASSWORD -e \"DROP DATABASE \\\`$DEV_SCHEMA\\\`;\""
}

dev_status() {
  print_params
  echo
  if pid_alive "$STATE_DIR/backend.pid"; then
    echo "后端: 运行中 (pid $(cat "$STATE_DIR/backend.pid"))"
  else
    echo "后端: 未运行"
  fi
  if pid_alive "$STATE_DIR/frontend.pid"; then
    echo "前端: 运行中 (pid $(cat "$STATE_DIR/frontend.pid"))"
  else
    echo "前端: 未运行"
  fi
}

dev_logs() {
  local which="${1:-}"
  case "$which" in
    back|backend) tail -f "$STATE_DIR/backend.log" ;;
    front|frontend) tail -f "$STATE_DIR/frontend.log" ;;
    *) echo "用法: dev.sh dev logs back|front" >&2; exit 1 ;;
  esac
}

# ---------------------------------------------------------------------------
# test 子命令：包一层 docker-compose.test.yml（5.1），只负责喂 slug 派生的隔离参数
# ---------------------------------------------------------------------------

compose_test() {
  COMPOSE_PROJECT_NAME="$TEST_PROJECT_NAME" \
  MYSQL_TEST_PORT="$MYSQL_TEST_PORT" \
  REDIS_TEST_PORT="$REDIS_TEST_PORT" \
  docker compose -f "$DOCS_DIR/docker-compose.test.yml" "$@"
}

test_up() {
  echo "▸ 拉起本 worktree（$SLUG）专属测试环境：$TEST_PROJECT_NAME"
  echo "  MySQL: localhost:$MYSQL_TEST_PORT   Redis: localhost:$REDIS_TEST_PORT"
  compose_test up -d
  echo "✔ 完成。默认镜像是 MySQL 5.7；跑 8.4 那条线加 MYSQL_IMAGE=mysql:8.4 环境变量后重跑本命令。"
}

test_down() {
  echo "▸ 清理本 worktree 专属测试环境：$TEST_PROJECT_NAME（down -v，不留残留卷）"
  compose_test down -v
}

test_status() {
  compose_test ps
}

# ---------------------------------------------------------------------------
# 入口
# ---------------------------------------------------------------------------

usage() { sed -n '2,44p' "$0"; }

main() {
  local group="${1:-}"; shift || true
  case "$group" in
    slug) print_params ;;
    dev)
      case "${1:-}" in
        up) dev_up ;;
        down) dev_down ;;
        status) dev_status ;;
        logs) shift; dev_logs "${1:-}" ;;
        *) usage; exit 1 ;;
      esac
      ;;
    test)
      case "${1:-}" in
        up) test_up ;;
        down) test_down ;;
        status) test_status ;;
        *) usage; exit 1 ;;
      esac
      ;;
    --help|-h|"") usage ;;
    *) usage; exit 1 ;;
  esac
}

main "$@"
