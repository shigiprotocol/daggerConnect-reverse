# ⚙️ DaggerConnect

<div align="center">

**ریورس تانل قدرتمند دگرکانکت**

[ویژگی‌ها](#-ویژگیها) • [نصب سریع](#-نصب-سریع) • [مستندات](#-راهنمای-استفاده) • [مثال‌ها](#-مثالها) • [پیکربندی](#-پیکربندی-پیشرفته)

</div>

<div align="center">

</div>

---

## 📖 فهرست مطالب

- [معرفی](#-معرفی)
- [ویژگی‌ها](#-ویژگیها)
- [نصب سریع](#-نصب-سریع)
- [راهنمای استفاده](#-راهنمای-استفاده)
- [مثال‌ها](#-مثالها)
- [پیکربندی پیشرفته](#-پیکربندی-پیشرفته)
- [بنچمارک](#-بنچمارک-و-عملکرد)

---

## 🎯 معرفی

یک راهکار حرفه‌ای برای ایجاد تونل‌های امن و پرسرعت معکوس بین سرورهاست که با بهره‌گیری از آخرین فناوری‌های شبکه، امکان انتقال ترافیک با کمترین تاخیر را فراهم می‌کند. این سیستم به‌طور خاص برای محیط‌های حساس به تاخیر و نیازمند امنیت بالا طراحی شده است.

### 🔥 چرا DaggerConnect?

✅ **سرعت بالا** - با استفاده از SMUX و KCP  
✅ **چند پروتکل** - TCP, KCP, WebSocket, WSS  
✅ **UDP Support** - پشتیبانی کامل از UDP (مناسب WireGuard, QUIC, OpenVPN)  
✅ **Traffic Obfuscation** - مخفی‌سازی ترافیک با padding و timing randomization  
✅ **Auto-reconnect** - اتصال مجدد خودکار  
✅ **Connection Pooling** - چندین اتصال همزمان برای load balancing  
✅ **پروفایل‌های آماده** - Balanced, Aggressive, Latency, CPU-Efficient, Gaming

---

## ⚡ ویژگی‌ها

### 🌐 پروتکل‌های پشتیبانی شده

| پروتکل | توضیحات | کاربرد |
|--------|---------|--------|
| **TCP** (tcpmux) | پایدار و سازگار | استفاده عمومی |
| **KCP** (kcpmux) | UDP-based، سریع | شبکه‌های پرافت |
| **WebSocket** (wsmux) | عبور از فایروال | محیط‌های محدود |
| **WSS** (wssmux) | WebSocket + TLS | امنیت بالا |

### 🎨 پروفایل‌های عملکرد

| پروفایل | تاخیر | CPU | پهنای باند | کاربرد |
|---------|-------|-----|-----------|--------|
| **balanced** | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ | استفاده روزمره |
| **aggressive** | ⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐⭐ | انتقال فایل |
| **latency** | ⭐⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐ | بازی، VoIP |
| **cpu-efficient** | ⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐ | سرورهای ضعیف |
| **gaming** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ | گیمینگ، Real-time |

### 🎭 Traffic Obfuscation (جدید!)

- ✨ **Random Padding** - اضافه کردن padding تصادفی برای مخفی کردن اندازه بسته‌ها
- ⏱️ **Timing Randomization** - تاخیر تصادفی برای شبیه‌سازی ترافیک طبیعی
- 📦 **Packet Chunking** - تقسیم بسته‌ها به chunk های متغیر
- 🎯 **Burst Mode** - ارسال سریع گاه‌به‌گاه برای شبیه‌سازی رفتار کاربر واقعی

### 🔧 قابلیت‌های پیشرفته

- ✨ **Stream Multiplexing** - چندین stream روی یک اتصال
- 🔄 **Load Balancing** - توزیع بار بین session‌ها
- 🛡️ **PSK Encryption** - رمزنگاری AES-GCM با Pre-Shared Key
- 📊 **Connection Pooling** - بهینه‌سازی تعداد اتصالات
- 🎯 **UDP Flow Management** - مدیریت هوشمند جریان UDP
- 📈 **Auto Buffer Tuning** - تنظیم خودکار بافرها
- 🔁 **Graceful Restart** - راه‌اندازی مجدد بدون قطعی

---

## 🚀 نصب سریع

### نصب خودکار با اسکریپت Installer

```bash
wget -O setup.sh https://raw.githubusercontent.com/itsFLoKi/DaggerConnect/main/setup.sh
chmod +x setup.sh
sudo bash setup.sh
```

### 📦 نصب دستی

```bash
# دانلود باینری
wget https://github.com/itsFLoKi/DaggerConnect/releases/download/v{NUMBER}/DaggerConnect
chmod +x DaggerConnect
sudo mv DaggerConnect /usr/local/bin/

# ایجاد دایرکتوری کانفیگ
sudo mkdir -p /etc/DaggerConnect

# تولید فایل کانفیگ
DaggerConnect -gen server  # برای سرور
DaggerConnect -gen client  # برای کلاینت
```

---

## 📚 راهنمای استفاده

### 🖥️ نصب سرور (ایران)

```bash
1. گزینه "1) Install Server" را انتخاب کنید
2. پروتکل مورد نظر را انتخاب کنید (توصیه: tcpmux)
3. پورت Tunnel را وارد کنید (مثال: 4000)
4. PSK (رمز ارتباط) را وارد کنید - در هر دو سرور باید یکسان باشد
5. پروفایل عملکرد را انتخاب کنید (توصیه: balanced)
6. فعال‌سازی Traffic Obfuscation (توصیه: Y)
7. پروتکل mapping را انتخاب کنید (tcp/udp/both)
8. پورت اسکریپتتون را وارد کنید (پورتی که کاربر به آن متصل میشود)
9. در صورت نیاز، mapping های دیگر اضافه کنید
```

### 💻 نصب کلاینت (سرور خارج)

```bash
1. گزینه "2) Install Client" را انتخاب کنید
2. همان PSK سرور را وارد کنید
3. همان پروفایل سرور را انتخاب کنید
4. فعال‌سازی Traffic Obfuscation (توصیه: Y)
5. پروتکل را انتخاب کنید (باید با سرور یکسان باشد)
6. آدرس سرور + پورت Tunnel را وارد کنید (مثال: 1.2.3.4:4000)
7. تعداد Connection Pool را وارد کنید (پیش‌فرض: 2)
8. Aggressive Pool را فعال کنید یا نه (توصیه: N)
9. Retry Interval و Dial Timeout را تنظیم کنید
10. در صورت نیاز، path های دیگر اضافه کنید
```

### ⚙️ مدیریت سرویس‌ها

```bash
# ورود به منوی تنظیمات
گزینه "3) Settings" در منوی اصلی

# عملیات‌های موجود:
1) Start - راه‌اندازی سرویس
2) Stop - توقف سرویس
3) Restart - راه‌اندازی مجدد
4) Status - مشاهده وضعیت
5) View Logs - مشاهده لاگ‌های زنده
6) Enable Auto-start - فعال‌سازی اجرای خودکار
7) Disable Auto-start - غیرفعال‌سازی اجرای خودکار
8) View Config - مشاهده کانفیگ
9) Edit Config - ویرایش کانفیگ
10) Delete Config & Service - حذف کامل
```

---

## 💡 مثال‌ها

### مثال 1: V2Ray/Xray Tunnel

#### سرور ایران (Server)
```yaml
mode: "server"
listen: "0.0.0.0:4000"
transport: "tcpmux"
psk: "my-super-secret-key-12345"
profile: "balanced"
verbose: false

maps:
  - type: tcp
    bind: "0.0.0.0:443"
    target: "127.0.0.1:443"

obfuscation:
  enabled: true
  min_padding: 16
  max_padding: 512
  min_delay_ms: 5
  max_delay_ms: 50
  burst_chance: 0.15
```

#### سرور خارج (Client)
```yaml
mode: "client"
psk: "my-super-secret-key-12345"
profile: "balanced"
verbose: false

paths:
  - transport: "tcpmux"
    addr: "IRAN_SERVER_IP:4000"
    connection_pool: 2
    aggressive_pool: false
    retry_interval: 3
    dial_timeout: 10

obfuscation:
  enabled: true
  min_padding: 16
  max_padding: 512
  min_delay_ms: 5
  max_delay_ms: 50
  burst_chance: 0.15
```

```bash
# V2Ray/Xray روی سرور خارج باید روی 127.0.0.1:443 listen کند
# کاربران به IRAN_SERVER_IP:443 متصل می‌شوند
```

---

### مثال 2: WireGuard Tunnel

#### سرور ایران
```yaml
mode: "server"
listen: "0.0.0.0:4000"
transport: "kcpmux"  # KCP برای UDP بهتره
psk: "wireguard-tunnel-key"
profile: "latency"
verbose: false

maps:
  - type: udp
    bind: "0.0.0.0:51820"
    target: "127.0.0.1:51820"

obfuscation:
  enabled: true
  min_padding: 16
  max_padding: 512
  min_delay_ms: 5
  max_delay_ms: 50
  burst_chance: 0.15
```

#### سرور خارج
```yaml
mode: "client"
psk: "wireguard-tunnel-key"
profile: "latency"
verbose: false

paths:
  - transport: "kcpmux"
    addr: "IRAN_SERVER_IP:4000"
    connection_pool: 3
    aggressive_pool: false
    retry_interval: 3
    dial_timeout: 10

obfuscation:
  enabled: true
  min_padding: 16
  max_padding: 512
  min_delay_ms: 5
  max_delay_ms: 50
  burst_chance: 0.15
```

```bash
# WireGuard روی سرور خارج باید روی 127.0.0.1:51820 listen کند
# کاربران به IRAN_SERVER_IP:51820 متصل می‌شوند
```

---

### مثال 3: SSH Reverse Tunnel

```yaml
# server.yaml (سرور ایران)
mode: "server"
listen: "0.0.0.0:4000"
transport: "tcpmux"
psk: "ssh-secure-key"
profile: "balanced"

maps:
  - type: tcp
    bind: "0.0.0.0:2222"
    target: "127.0.0.1:22"

obfuscation:
  enabled: true
```

```bash
# اتصال از کلاینت:
ssh -p 2222 user@IRAN_SERVER_IP
```

---

### مثال 4: Multi-Service Setup

```yaml
# server.yaml
mode: "server"
listen: "0.0.0.0:4000"
transport: "tcpmux"
psk: "multi-service-key"
profile: "balanced"

maps:
  # HTTPS
  - type: tcp
    bind: "0.0.0.0:443"
    target: "127.0.0.1:8443"
  
  # HTTP
  - type: tcp
    bind: "0.0.0.0:80"
    target: "127.0.0.1:8080"
  
  # SSH
  - type: tcp
    bind: "0.0.0.0:2222"
    target: "127.0.0.1:22"
  
  # WireGuard
  - type: udp
    bind: "0.0.0.0:51820"
    target: "127.0.0.1:51820"

obfuscation:
  enabled: true
```

---

### مثال 5: Gaming Server (Low Latency)

```yaml
# server.yaml
mode: "server"
listen: "0.0.0.0:4000"
transport: "kcpmux"
psk: "gaming-server-key"
profile: "gaming"  # پروفایل gaming
verbose: false

maps:
  # Minecraft
  - type: tcp
    bind: "0.0.0.0:25565"
    target: "127.0.0.1:25565"
  
  # CS:GO
  - type: udp
    bind: "0.0.0.0:27015"
    target: "127.0.0.1:27015"
  - type: tcp
    bind: "0.0.0.0:27015"
    target: "127.0.0.1:27015"

obfuscation:
  enabled: false  # برای گیمینگ بهتره خاموش باشه
```

---

### مثال 6: Multi-Path Load Balancing

```yaml
# client.yaml
mode: "client"
psk: "load-balance-key"
profile: "aggressive"

paths:
  # Path 1: TCP
  - transport: "tcpmux"
    addr: "server1.example.com:4000"
    connection_pool: 3
    aggressive_pool: true
    retry_interval: 3
    dial_timeout: 10
  
  # Path 2: KCP
  - transport: "kcpmux"
    addr: "server2.example.com:4000"
    connection_pool: 2
    aggressive_pool: true
    retry_interval: 3
    dial_timeout: 10
  
  # Path 3: WebSocket
  - transport: "wsmux"
    addr: "server3.example.com:8080"
    connection_pool: 2
    aggressive_pool: false
    retry_interval: 5
    dial_timeout: 15

obfuscation:
  enabled: true
```

---

## ⚙️ پیکربندی پیشرفته

### 🎭 Traffic Obfuscation Settings

```yaml
obfuscation:
  enabled: true           # فعال/غیرفعال سازی obfuscation
  min_padding: 16         # حداقل padding (بایت)
  max_padding: 512        # حداکثر padding (بایت)
  min_delay_ms: 5         # حداقل تاخیر (میلی‌ثانیه)
  max_delay_ms: 50        # حداکثر تاخیر (میلی‌ثانیه)
  burst_chance: 0.15      # احتمال burst mode (0.0-1.0)
```

#### 🎯 توصیه‌های Obfuscation:

| سناریو | enabled | padding | delay | burst |
|---------|---------|---------|-------|-------|
| **Maximum Stealth** | true | 128-1024 | 10-100 | 0.2 |
| **Balanced** | true | 16-512 | 5-50 | 0.15 |
| **Performance** | true | 8-256 | 2-20 | 0.1 |
| **Gaming/VoIP** | false | - | - | - |

---

### 🔧 Path Configuration (Client)

```yaml
paths:
  - transport: "tcpmux"              # نوع transport
    addr: "server.example.com:4000"  # آدرس و پورت سرور
    connection_pool: 2               # تعداد اتصالات همزمان
    aggressive_pool: false           # حالت aggressive pooling
    retry_interval: 3                # فاصله retry (ثانیه)
    dial_timeout: 10                 # timeout اتصال (ثانیه)
```

#### 📊 Connection Pool Guidelines:

| شرایط شبکه | Pool Size | Aggressive |
|------------|-----------|------------|
| **Stable, High Speed** | 2 | false |
| **Normal** | 3-4 | false |
| **Unstable** | 5-6 | true |
| **High Load** | 6-8 | true |

---

## 🎮 مدیریت Systemd Service

### Server Service

```bash
# شروع
sudo systemctl start DaggerConnect-server

# توقف
sudo systemctl stop DaggerConnect-server

# راه‌اندازی مجدد
sudo systemctl restart DaggerConnect-server

# فعال‌سازی auto-start
sudo systemctl enable DaggerConnect-server

# وضعیت
sudo systemctl status DaggerConnect-server
```

### Client Service

```bash
# شروع
sudo systemctl start DaggerConnect-client

# توقف
sudo systemctl stop DaggerConnect-client

# راه‌اندازی مجدد
sudo systemctl restart DaggerConnect-client

# فعال‌سازی auto-start
sudo systemctl enable DaggerConnect-client

# وضعیت
sudo systemctl status DaggerConnect-client
```

### 📋 مشاهده Logs

```bash
# Server logs (زنده)
journalctl -u DaggerConnect-server -f

# Client logs (زنده)
journalctl -u DaggerConnect-client -f

# آخرین 100 خط
journalctl -u DaggerConnect-server -n 100

# لاگ‌های امروز
journalctl -u DaggerConnect-server --since today

# لاگ‌های یک ساعت گذشته
journalctl -u DaggerConnect-client --since "1 hour ago"
```

---

## 📊 بنچمارک و عملکرد

### مقایسه پروتکل‌ها

| پروتکل | تاخیر (ms) | پهنای باند (Mbps) | CPU (%) | حافظه (MB) |
|--------|-----------|------------------|---------|-----------|
| **tcpmux** | 15 | 850 | 8 | 45 |
| **kcpmux** | 12 | 920 | 15 | 65 |
| **wsmux** | 18 | 780 | 10 | 50 |
| **wssmux** | 20 | 750 | 12 | 55 |

*تست شده با connection pool=4, profile=balanced, شبکه 1Gbps*

### مقایسه پروفایل‌ها (با KCP)

| پروفایل | تاخیر (ms) | Throughput (Mbps) | CPU (%) | RAM (MB) |
|---------|-----------|-------------------|---------|----------|
| **cpu-efficient** | 25 | 450 | 5 | 40 |
| **balanced** | 15 | 750 | 10 | 50 |
| **latency** | 8 | 900 | 18 | 60 |
| **aggressive** | 10 | 950 | 22 | 70 |
| **gaming** | 7 | 920 | 20 | 65 |

### تأثیر Obfuscation بر عملکرد

| حالت | تاخیر اضافه (ms) | CPU اضافه (%) | Throughput (%) |
|------|------------------|---------------|----------------|
| **Disabled** | 0 | 0 | 100% |
| **Light (8-256)** | 2-5 | 2-3 | 95% |
| **Balanced (16-512)** | 5-15 | 5-8 | 90% |
| **Heavy (128-1024)** | 15-30 | 10-15 | 80% |

---

## 🔒 امنیت

### 1️⃣ تولید PSK قوی

```bash
# روش 1: OpenSSL
openssl rand -base64 32

# روش 2: /dev/urandom
head -c 32 /dev/urandom | base64

# روش 3: pwgen
pwgen -s 64 1
```

### 2️⃣ استفاده از TLS (WSS)

```bash
# تولید self-signed certificate
openssl req -x509 -newkey rsa:4096 -nodes \
  -keyout /etc/DaggerConnect/key.pem \
  -out /etc/DaggerConnect/cert.pem \
  -days 365 -subj "/CN=yourdomain.com"
```

```yaml
# server.yaml
transport: "wssmux"
cert_file: "/etc/DaggerConnect/cert.pem"
key_file: "/etc/DaggerConnect/key.pem"
```

### 3️⃣ فایروال و محدودیت دسترسی

```bash
# فقط IP مشخص
sudo ufw allow from 1.2.3.4 to any port 4000

# محدود کردن rate
sudo ufw limit 4000/tcp

# چک وضعیت
sudo ufw status numbered
```

### 4️⃣ Obfuscation برای مخفی‌سازی ترافیک

```yaml
obfuscation:
  enabled: true
  min_padding: 128
  max_padding: 1024
  min_delay_ms: 10
  max_delay_ms: 100
  burst_chance: 0.2
```

---

## 🛠️ عیب‌یابی (Troubleshooting)

### ❌ سرور اجرا نمیشه

```bash
# چک کردن پورت
sudo netstat -tlnp | grep 4000

# چک کردن سرویس
sudo systemctl status DaggerConnect-server

# مشاهده لاگ‌های خطا
journalctl -u DaggerConnect-server -n 50
```

### ❌ کلاینت متصل نمیشه

```bash
# تست اتصال به سرور
telnet SERVER_IP 4000

# چک کردن PSK
# PSK باید در هر دو سرور یکسان باشد

# چک کردن فایروال
sudo ufw status
```

### ❌ سرعت کمه

```bash
# افزایش Connection Pool
paths:
  - connection_pool: 6  # به جای 2

# تغییر پروفایل به aggressive
profile: "aggressive"

# استفاده از KCP
transport: "kcpmux"
```

### ❌ تاخیر زیاده

```bash
# تغییر پروفایل
profile: "latency"

# غیرفعال کردن Obfuscation
obfuscation:
  enabled: false
```

---

## 📈 ابزارهای نظارت

### تست سرعت با iperf3

```bash
# نصب iperf3
sudo apt install iperf3

# سرور (روی سرور خارج)
iperf3 -s -p 5201

# کلاینت (از سرور ایران یا کامپیوتر شخصی)
iperf3 -c IRAN_SERVER_IP -p 5201 -t 30
```

### نظارت بر ترافیک

```bash
# نصب iftop
sudo apt install iftop

# مشاهده ترافیک لحظه‌ای
sudo iftop -i eth0

# نمایش آمار
vnstat -l
```

### نظارت بر منابع سیستم

```bash
# CPU و RAM
htop

# فقط DaggerConnect
ps aux | grep DaggerConnect

# استفاده از منابع
pidstat -p $(pgrep DaggerConnect) 1
```

---

## 🔄 آپدیت

### آپدیت از طریق Installer

```bash
sudo bash setup.sh
# گزینه 4) Update Core را انتخاب کنید
```

### آپدیت دستی

```bash
# دانلود نسخه جدید
wget https://github.com/itsFLoKi/DaggerConnect/releases/download/v{VERSION}/DaggerConnect

# توقف سرویس
sudo systemctl stop DaggerConnect-server
sudo systemctl stop DaggerConnect-client

# جایگزینی باینری
chmod +x DaggerConnect
sudo mv DaggerConnect /usr/local/bin/

# راه‌اندازی مجدد
sudo systemctl start DaggerConnect-server
sudo systemctl start DaggerConnect-client
```

---

## 📝 سوالات متداول (FAQ)

### ❓ چه تفاوتی بین TCP و KCP هست؟

- **TCP (tcpmux)**: پایدار، کمترین CPU، مناسب شبکه‌های باثبات
- **KCP (kcpmux)**: سریع‌تر، مناسب شبکه‌های پرافت، CPU بیشتر

### ❓ چه زمانی Obfuscation رو فعال کنم؟

فعال کنید اگر:
- DPI/Filtering وجود داره
- ترافیک شما تحت نظارته
- میخواید pattern های ترافیک رو مخفی کنید

غیرفعال کنید اگر:
- سرعت و تاخیر اولویت اوله
- برای gaming/VoIP استفاده میکنید

### ❓ Connection Pool چقدر باید باشه؟

- **شبکه پایدار**: 2-3
- **شبکه معمولی**: 4-5
- **شبکه ناپایدار**: 6-8
- **بار بالا**: 8-10

### ❓ چطور امنیت رو بالا ببرم؟

1. از PSK قوی استفاده کنید (32+ کاراکتر)
2. WSS را فعال کنید
3. Obfuscation را روشن کنید
4. فقط IP مشخص رو allow کنید
5. فایروال را درست تنظیم کنید

---

## 📞 پشتیبانی

- 🐛 [گزارش باگ](https://github.com/itsFLoKi/DaggerConnect/issues)
- 💬 [بحث و گفتگو](https://github.com/itsFLoKi/DaggerConnect/discussions)
- 📧 **Telegram**: [Support](https://t.me/DDDDDTRIPLE)

---

## 🙏 تشکر

- [xtaci/smux](https://github.com/xtaci/smux) - Stream multiplexing library
- [xtaci/kcp-go](https://github.com/xtaci/kcp-go) - KCP protocol implementation
- [gorilla/websocket](https://github.com/gorilla/websocket) - WebSocket library

---

## 📝 لایسنس

این پروژه تحت لایسنس اختصاصی منتشر شده و open-source نیست. تمامی حقوق محفوظ است.

---

<div align="center">

⭐ **اگه مفید بود یه ستاره بدید!** ⭐

Made with ❤️ by [itsFLoKi](https://github.com/itsFLoKi)

[⬆ برگشت به بالا](#-daggerconnect)

</div>
