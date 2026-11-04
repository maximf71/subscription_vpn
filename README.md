# VPN subscription mirror

Подписка для Happ / v2rayN / Streisand / v2rayNG / Hiddify.

Сейчас в подписке **Hysteria2**:
- 🇩🇪 Германия — UDP 443 + hop UDP 20000
- 🇯🇵 Япония (Tokyo) — после установки (см. ниже)

## Ссылка для клиента

```
https://raw.githubusercontent.com/maximf71/subscription_vpn/main/sub.txt#Мой-VPS
```

В Happ: **+ → Add subscription** → вставить ссылку выше → Update.

## Установка Японии (Hysteria2 latest)

Сервер `23.131.136.70` сейчас **не принимает входящие SSH** с интернета
(таймаут на 22/39266 со всех точек проверки). Нужна **веб-консоль / VNC**
в панели хостинга (или откройте SSH/firewall в панели).

В консоли под root:

```bash
curl -fsSL https://raw.githubusercontent.com/maximf71/subscription_vpn/main/install-hysteria2-jp.sh -o /tmp/install-hy2.sh
chmod +x /tmp/install-hy2.sh
export GH_PAT='ВАШ_GITHUB_PAT'
bash /tmp/install-hy2.sh
```

Скрипт:
1. Ставит **последний** Hysteria2
2. Поднимает узлы UDP **443** + hop **20000** (obfs salamander, masquerade)
3. Включает BBR
4. Обновляет этот репозиторий (`sub.txt`) — Япония появится в подписке Happ

После установки в Happ нажмите **Update** у подписки.
