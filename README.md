# DNS Spoofing / DNS Poisoning - Envenenamiento de Caché DNS

## 📋 Descripción General

Este repositorio documenta técnicas avanzadas de ataque DNS contra resolución de nombres. Específicamente, cubre **DNS Spoofing** (suplantación de respuestas DNS) y **DNS Poisoning** (envenenamiento de caché) para redirigir tráfico de usuarios hacia servidores maliciosos controlados por el atacante.

El caso de estudio se enfoca en comprometer el dominio **`itla.edu.do`** dirigiendo usuarios a un sitio web fijo controlado por el atacante.

---

## 🔍 Conceptos Fundamentales

### ¿Qué es DNS?

**DNS (Domain Name System)** es el protocolo responsable de traducir nombres de dominio legibles por humanos (ej: `google.com`) en direcciones IP (ej: `142.251.46.102`).

```
Usuario:  "Quiero acceder a facebook.com"
   ↓
Cliente DNS: "¿Cuál es la IP de facebook.com?"
   ↓
Servidor DNS: "Es 102.132.192.87"
   ↓
Usuario: Se conecta a 102.132.192.87
   ↓
Recibe: FACEBOOK (porque la IP es correcta)
```

### El Ataque: Respuesta DNS Falsificada

```
Usuario:  "¿Cuál es la IP de itla.edu.do?"
   ↓
Query DNS ──→ Servidor DNS legítimo
   │
   ├─ Pero ANTES de llegar al servidor
   │  el atacante intercepta
   │  la respuesta legítima
   │
   ├─ El atacante envía respuesta falsa:
   │  "itla.edu.do → IP: 192.168.1.100"
   │  (Servidor malicioso del atacante)
   │
   └─ Usuario recibe PRIMERO la falsa
      respuesta DNS falsa
      
   ↓
Usuario se conecta a: 192.168.1.100 (atacante)
   ↓
Recibe: SITIO MALICIOSO (phishing, etc.)
   ↓
COMPROMISO: Robo de credenciales, inyección, etc.
```

---

## 💥 El Flujo Completo del Ataque

### Fase 1: ARP Spoofing Previo (Prerequisito)

Antes de poder interceptar DNS, el atacante debe estar en la posición de MITM (Man-in-the-Middle):

```
Topología Original:
┌────────────┐         ┌─────────────────┐         ┌─────────────┐
│   Usuario  │────────→│ Gateway (Router) │────────→│ DNS Server  │
│ 192.168... │ ←───────│   192.168.1.1   │ ←───────│  8.8.8.8    │
└────────────┘         └─────────────────┘         └─────────────┘

Topología Comprometida (ARP Spoofing):
┌────────────┐         ┌──────────────────┐        │
│   Usuario  │────────→│ Atacante (MITM)  │────→   Router
│ 192.168... │ ←───────│  aa:bb:cc:dd:ee  │ ←────  192.168.1.1
└────────────┘         └──────────────────┘        │
                              ↓
                    ┌─────────────────────┐
                    │ Usuario cree que    │
                    │ habla con gateway   │
                    │ pero habla con      │
                    │ el atacante         │
                    └─────────────────────┘

ARP Spoofing falsifica tablas ARP:
Usuario: ¿MAC del gateway? → Respuesta: AA:BB:CC:DD:EE (atacante)
Gateway: ¿MAC del usuario? → Respuesta: AA:BB:CC:DD:EE (atacante)

Resultado: Atacante intercepta TODO el tráfico ✓
```

### Fase 2: Interceptación de Peticiones DNS

```bash
Bettercap escucha en puerto UDP 53:

Usuario:  DNS query "itla.edu.do"
   ↓
Paquete UDP destino 8.8.8.8:53
   ↓
Interceptado por Bettercap (MITM)
   │
   └─→ ¿Es consulta de "itla.edu.do"?
       SÍ → Respuesta falsa
       NO → Dejar pasar al servidor legítimo
```

### Fase 3: Respuesta DNS Falsa

```
Paquete DNS Legítimo:
┌─────────────────────────────────┐
│ Query: itla.edu.do              │
│ Tipo: A (IPv4)                  │
│ Servidor: 8.8.8.8               │
└─────────────────────────────────┘
     ↓ viaja a través de atacante

Respuesta Falsa Inyectada:
┌─────────────────────────────────┐
│ Query: itla.edu.do ✓            │
│ Respuesta: 192.168.1.100        │ ← Servidor malicioso
│ TTL: 3600 (1 hora)              │
│ Autoridad: ficticia.edu.do      │
└─────────────────────────────────┘
     ↓ Usuario recibe PRIMERO

Usuario → 192.168.1.100 (Atacante)
         ↓
    Sitio web suplantado
    (Phishing de ITLA)
    Robo de credenciales
```

---

## 🛠️ Herramienta Utilizada: Bettercap

**Bettercap** es una herramienta de penetration testing moderna que permite realizar ataques MITM sofisticados, incluyendo ARP spoofing, DNS spoofing, HTTPS stripping, y más.

### Características Relevantes

```
Bettercap v2.32.0
├─ ARP Spoofing: Posicionarse como MITM
├─ DNS Spoofing: Inyectar respuestas DNS falsas
├─ HTTPS Stripping: Downgrade de conexiones seguras
├─ Proxy: Interceptación de tráfico
├─ Sniffer: Captura de tráfico en tiempo real
└─ Módulos: Extensibles para ataques personalizados
```

### Instalación

```bash
# Debian/Ubuntu
sudo apt-get install bettercap

# Verificar
bettercap --version
# Expected: Bettercap v2.x.x
```

---

## 📊 Tipos de Ataques DNS

### Tipo 1: DNS Spoofing (Este Repositorio)

```
┌────────────────────────────┐
│ DNS Spoofing               │
├────────────────────────────┤
│ Mecanismo: Interceptar     │
│ respuesta DNS en tránsito  │
│                            │
│ Requisito: MITM position   │
│ (ARP Spoofing previo)      │
│                            │
│ Dominio: itla.edu.do       │
│ Respuesta falsa: 192.168.1 │
│                            │
│ Ventaja: Inmediato         │
│ Desventaja: No persiste    │
│            (después del TTL)
└────────────────────────────┘
```

### Tipo 2: DNS Poisoning (Caché)

```
┌────────────────────────────┐
│ DNS Poisoning              │
├────────────────────────────┤
│ Mecanismo: Contaminar      │
│ caché del servidor DNS     │
│                            │
│ Requisito: Acceso al DNS   │
│ o vulnerabilidad de suplant│
│                            │
│ Efecto: Persiste horas/días│
│ Afecta: TODO el rango local│
│         (después CITLA)    │
│                            │
│ Complejidad: ALTA          │
│ Tasa éxito: MEDIA          │
└────────────────────────────┘
```

**Este repositorio cubre el Tipo 1: DNS Spoofing con ARP Spoofing previo**

---

## 🎯 Caso de Estudio: ITLA.EDU.DO

### Escenario Vulnerable

```
Red Local (LAN) del ITLA:
┌──────────────────────────────┐
│ Subnet: 192.168.1.0/24      │
├──────────────────────────────┤
│ Gateway: 192.168.1.1        │ ← Atacante spoofea esto
│ DNS: 8.8.8.8 (Google)       │ ← Usuario consulta aquí
│                             │
│ Usuarios: 192.168.1.50-254  │
│ Servidores: 192.168.1.10-40 │
└──────────────────────────────┘

Problemas de Seguridad:
1. No hay validación de ARP responses
2. Usuarios confían en cualquier DNS response
3. No hay DNSSEC implementado
4. DHCP no está protegido
5. No hay monitoreo de tráfico DNS
```

### El Ataque en Acción

```
Paso 1: Atacante empieza Bettercap con ARP Spoofing

$ sudo bettercap -iface eth0 \
    -T 192.168.1.0/24 \
    -O 192.168.1.1

$ set arp.spoof.targets 192.168.1.50-254
$ run

Resultado: Atacante intercepta TODO tráfico
          desde 192.168.1.50-254 → Gateway

Paso 2: Configurar DNS Spoofing

$ set dns.spoof.domains itla.edu.do
$ set dns.spoof.address 192.168.1.100

Resultado: Cuando usuario pregunta por itla.edu.do
          Recibe: 192.168.1.100 (servidor del atacante)

Paso 3: Servidor web malicioso escucha en :80

$ sudo python3 http_server.py \
    --port 80 \
    --ssl-cert fake.crt

Resultado: Usuario accede a sitio suplantado
```

---

## 📁 Estructura del Repositorio

```
DNS-Spoofing-DNS-Poisoning/
├── README.md                          # Este archivo
├── GUIA_DE_USO.md                    # Instrucciones prácticas
├── EXPLICACION_TECNICA.md            # Análisis profundo de DNS
├── MITIGACION.md                     # DNSSEC y defensas
├── GITHUB_SETUP.sh                   # Script de GitHub
│
├── configuraciones/
│   ├── bettercap_dns_spoofing.conf   # Configuración Bettercap
│   ├── dns_spoof_rules.json          # Reglas de spoofing
│   └── fake_web_server.py            # Servidor malicioso demo
│
└── imagenes/                         # Evidencia fotográfica
    ├── image_bettercap_setup.png     # Interfaz Bettercap
    ├── image_dns_spoofing_wireshark.png
    ├── image_phishing_page.png       # Sitio suplantado
    └── image_network_flow.png        # Diagrama del ataque
```

---

## 🚀 Flujo de Aprendizaje

1. **Entender fundamentos**: Lee `EXPLICACION_TECNICA.md`
   - Cómo funciona DNS
   - Estructura de paquetes DNS
   - Por qué ARP Spoofing es necesario

2. **Preparar laboratorio**: Sigue `GUIA_DE_USO.md`
   - Topología de red
   - Instalación de herramientas
   - Configuración inicial

3. **Ejecutar ataque**:
   - ARP Spoofing con Bettercap
   - DNS Spoofing de itla.edu.do
   - Validar con Wireshark

4. **Implementar defensa**: Consulta `MITIGACION.md`
   - DNSSEC: Validación criptográfica
   - DHCP Snooping: ARP validation
   - Monitoreo de DNS

---

## 🔐 Requisitos de Seguridad

- **Red**: Lab aislada o máquina virtual
- **Herramientas**: Bettercap, Wireshark, Python
- **Conocimiento**: TCP/IP básico, DNS, ARP
- **Autorización**: Permiso explícito para auditoría

---

## ⚠️ Advertencia Legal y Ético

### Uso PERMITIDO
✅ Laboratorios educativos controlados
✅ Auditorías de red autorizadas
✅ Pruebas de seguridad propias
✅ Red de laboratorio aislada

### Uso PROHIBIDO
❌ Ataque a dominios sin autorización
❌ Interceptación de tráfico no autorizado
❌ Redirección maliciosa de servicios
❌ Phishing o robo de credenciales

**Legal**: El acceso no autorizado a sistemas es ilegal en mayoría de países.
**Responsabilidad**: El usuario es responsable de cualquier daño causado.

---

## 👨‍🎓 Contexto Académico

Proyecto académico de ciberseguridad del ITLA.

**Serie Completa de Ataques L2/L3**:
1. 🔗 [VTP Attacks](https://github.com/FAVA-007/VTP-Attacks)
2. 🔄 [DTP VLAN Hopping](https://github.com/FAVA-007/DTP-VLAN-Hopping)
3. 🕵️ [DNS Spoofing/Poisoning](https://github.com/FAVA-007/DNS-Spoofing-DNS-Poisoning)

---

**Última actualización**: Febrero 2026  
**Estado**: Completado ✅
