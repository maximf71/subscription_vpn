# VPN subscription mirror

Подписка для Happ / v2rayN / Streisand / v2rayNG / Hiddify.

Сейчас в подписке **Hysteria2**:
- 🇩🇪 Германия — UDP 443 + hop UDP 20000
- 🇯🇵 Япония (Tokyo) — после установки через консоль VPS

## Ссылка для клиента (Happ)

```
https://raw.githubusercontent.com/maximf71/subscription_vpn/main/sub.txt#Мой-VPS
```

В Happ: **+ → Add subscription** → вставить ссылку → Update.

## Установка Японии (Hysteria2 latest)

Сервер `23.131.136.70`: входящий SSH с интернета **не отвечает** (порт открыт на TCP, но баннера SSH нет; GitHub Actions тоже не достучался). Нужна **веб-консоль / VNC** в панели хостинга.

### 1) В панели хостинга откройте Security Group / Firewall

Разрешите входящие:
- TCP `39266` (SSH)
- UDP `443` + TCP `443` (Hysteria2)
- UDP `20000` (hop)

### 2) В VNC/Console под root выполните:

```bash
curl -fsSL https://raw.githubusercontent.com/maximf71/subscription_vpn/main/install-hysteria2-jp.sh -o /tmp/install-hy2.sh
chmod +x /tmp/install-hy2.sh
export GH_PAT='ВАШ_GITHUB_PAT'
bash /tmp/install-hy2.sh
```

Скрипт ставит последний Hysteria2, поднимает UDP 443 + hop 20000 (obfs salamander + masquerade), включает BBR и обновляет `sub.txt` в этом репозитории.

После успеха в Happ нажмите **Update** у подписки — появятся узлы 🇯🇵 Япония.
