#!/usr/bin/env bash
set -u

home="${HOME}"
db2="${home}/Library/Group Containers/group.com.apple.usernoted/db2/db"
db1="${home}/Library/Group Containers/group.com.apple.usernoted/db/db"

echo "== WorkPet macOS 通知诊断 =="
echo

echo "== 通知数据库路径 =="
for db in "$db2" "$db1"; do
  if [[ -e "$db" ]]; then
    echo "存在: $db"
  else
    echo "不存在: $db"
  fi
done
echo

selected_db=""
for db in "$db2" "$db1"; do
  if [[ -e "$db" ]]; then
    selected_db="$db"
    break
  fi
done

if [[ -n "$selected_db" ]]; then
  echo "== sqlite 读取测试 =="
  if sqlite3 "$selected_db" "SELECT count(*) FROM record;" >/tmp/workpet-notification-count.txt 2>/tmp/workpet-notification-error.txt; then
    echo "OK: 可读取 $selected_db"
    echo "record 数量: $(cat /tmp/workpet-notification-count.txt)"
    echo

    echo "== 最近 20 条通知来源 =="
    sqlite3 -separator $'\t' "$selected_db" \
      "SELECT app_id,enclosing_app_id,substr(coalesce(subtitle_text,''),1,40),substr(coalesce(body_text,''),1,80),date_created FROM record ORDER BY date_created DESC LIMIT 20;"
    echo

    echo "== 最近 20 条微信/飞书候选通知 =="
    sqlite3 -separator $'\t' "$selected_db" \
      "SELECT app_id,enclosing_app_id,substr(coalesce(subtitle_text,''),1,40),substr(coalesce(body_text,''),1,120),date_created FROM record WHERE lower(coalesce(app_id,'') || ' ' || coalesce(enclosing_app_id,'') || ' ' || coalesce(subtitle_text,'') || ' ' || coalesce(body_text,'')) LIKE '%wechat%' OR coalesce(app_id,'') LIKE '%xinWeChat%' OR coalesce(enclosing_app_id,'') LIKE '%xinWeChat%' OR lower(coalesce(app_id,'') || ' ' || coalesce(enclosing_app_id,'')) LIKE '%lark%' ORDER BY date_created DESC LIMIT 20;"
  else
    echo "失败: 无法读取 $selected_db"
    cat /tmp/workpet-notification-error.txt
    echo
    echo "处理建议: 给当前终端或 WorkPet.app 授予“完全磁盘访问权限”，然后重启终端/App。"
  fi
else
  echo "失败: 未找到 macOS 通知数据库。"
fi

echo
echo "== 微信/飞书 App bundle id =="
for app in "/Applications/WeChat.app" "/Applications/Lark.app" "/Applications/Feishu.app"; do
  if [[ -e "$app/Contents/Info.plist" ]]; then
    bundle_id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Contents/Info.plist" 2>/dev/null || true)
    echo "$app -> ${bundle_id:-未知}"
  fi
done

echo
echo "== 辅助功能 UI 自动化测试 =="
if osascript -e 'tell application "System Events" to get name of every process' >/tmp/workpet-system-events.txt 2>/tmp/workpet-system-events-error.txt; then
  echo "OK: 当前终端可访问 System Events。"
  echo "可见进程中的微信/飞书:"
  grep -E "WeChat|Lark|Feishu|微信|飞书" /tmp/workpet-system-events.txt || true
else
  echo "失败: 当前终端无法访问 System Events。"
  cat /tmp/workpet-system-events-error.txt
  echo
  echo "处理建议: 给当前终端或 WorkPet.app 授予“辅助功能”权限，然后重启终端/App。"
fi
