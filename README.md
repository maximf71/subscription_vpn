# VPN subscription mirror

Подписка для Happ / v2rayN / Streisand.

## Ссылка для клиента

```
https://raw.githubusercontent.com/maximf71/subscription_vpn/main/sub.txt
```

В Happ: **+ → Add subscription** → вставить ссылку выше.

## Обновление файла sub.txt

На машине с доступом к серверу:

```bash
curl -sk "https://130.78.12.100:2096/857v7sit7kdv9k8p/7e6a9x49oimx3kio" -o sub.txt
git add sub.txt && git commit -m "Update subscription" && git push
```
