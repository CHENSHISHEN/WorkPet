# 消息应用规则配置

WorkPet 使用 `source-rules.json` 控制哪些消息可以通过宠物提醒。配置同时适用于微信、飞书，以及后续接入的其他消息应用。

内置配置路径：

```text
WorkPet/Sources/WorkPet/Resources/source-rules.json
```

## 规则顺序

1. 先按 `bundleIdentifiers` 判断消息属于哪个应用。
2. 再判断消息分类：`direct`、`group`、`official`、`system`、`unknown`。
3. 黑名单优先，命中后按黑名单 `level` 处理。
4. 白名单其次，命中后按白名单 `level` 处理。
5. 都没命中时，使用分类默认等级。
6. 分类也没有命中时，使用应用默认等级。

`level` 支持：

- `strong`：强提醒。
- `normal`：普通提醒。
- `silent`：静默，不弹宠物通知。

## 消息分类

```json
"categories": {
  "direct": "normal",
  "group": "silent",
  "official": "silent",
  "system": "silent",
  "unknown": "silent"
}
```

分类含义：

- `direct`：个人私聊。
- `group`：群聊。
- `official`：公众号、订阅号、服务号等。
- `system`：登录、安全、系统通知。
- `unknown`：暂时无法识别的消息。

当前分类由通知标题、正文和 payload 里的关键词推断。后续微信/飞书解析更精确时，会优先使用 adapter 写入的 `messageCategory`。

## 白名单

白名单用于允许某些消息通过，或提升为强提醒。

```json
"whitelist": [
  {
    "category": "direct",
    "senderContains": ["老板", "领导", "家人"],
    "level": "strong"
  },
  {
    "senderContains": ["重要客户群", "线上故障群"],
    "level": "strong"
  },
  {
    "contains": ["紧急", "故障", "线上", "@我"],
    "level": "strong"
  }
]
```

## 黑名单

黑名单优先级高于白名单，适合屏蔽广告、公众号、低价值群消息。

```json
"blacklist": [
  {
    "category": "official",
    "level": "silent"
  },
  {
    "senderContains": ["订阅号", "服务号", "广告"],
    "level": "silent"
  },
  {
    "contains": ["优惠券", "秒杀", "促销", "直播"],
    "level": "silent"
  }
]
```

## 匹配字段

每条白名单/黑名单规则支持：

- `category`：匹配消息分类。
- `senderContains`：匹配发送人、会话名或群名。
- `titleContains`：匹配通知标题。
- `bodyContains`：匹配通知正文。
- `contains`：匹配发送人、标题、正文和原始 payload 任意位置。
- `level`：命中后的提醒等级。

## 新增应用

新增消息应用时，在 `messageApps` 增加一个条目即可：

```json
{
  "id": "slack",
  "displayName": "Slack",
  "bundleIdentifiers": ["com.tinyspeck.slackmacgap"],
  "defaultLevel": "silent",
  "categories": {
    "direct": "normal",
    "group": "silent",
    "official": "silent",
    "system": "normal",
    "unknown": "silent"
  },
  "whitelist": [
    {
      "contains": ["urgent", "@负责人"],
      "level": "strong"
    }
  ],
  "blacklist": []
}
```
