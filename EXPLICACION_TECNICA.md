# EXPLICACIÓN TÉCNICA: DNS Spoofing y Poisoning

## 🔬 Arquitectura del Sistema DNS

### El Proceso Normal de Resolución DNS

```
Usuario escribe en navegador: www.itla.edu.do
     ↓
Cliente DNS en SO local
     ├─ Revisa caché local (~5 minutos)
     ├─ Si no (cache miss):
     │   └─ Consulta servidor DNS configurado (8.8.8.8)
     ↓
Servidor DNS Recursor (8.8.8.8)
     ├─ Revisa su caché
     ├─ Si no, consulta servidores autoritativos:
     │   ├─ Root nameserver: ".com"
     │   ├─ TLD nameserver: "itla.edu.do"
     │   └─ Nameserver autoritativo: itla.edu.do
     ↓
Response viaja de vuelta: 192.168.50.10
     ↓
Usuario conecta a 192.168.50.10 ✓ Correcto
```

### Estructura de Paquete DNS (RFC 1035)

```
┌────────────────────────────────────────┐
│  DNS Header (12 bytes)                 │
├───────────┬─────────────────────────────┤
│ ID        │ Transaction ID (2 bytes)    │
├───────────┼─────────────────────────────┤
│ Flags     │ Query/Response bit          │
│           │ Opcode (Standard Query)     │
│           │ AA, TC, RD, RA bits         │
├───────────┼─────────────────────────────┤
│ QDCOUNT   │ Número de preguntas (1)    │
│ ANCOUNT   │ Número de respuestas       │
│ NSCOUNT   │ Número de records NS       │
│ ARCOUNT   │ Número de records adicionales
├────────────────────────────────────────┤
│  Question Section (Variable)            │
├────────────────────────────────────────┤
│ QNAME     │ "itla.edu.do" (Encoded)    │
│ QTYPE     │ A (IPv4) = 1               │
│ QCLASS    │ IN (Internet) = 1          │
├────────────────────────────────────────┤
│  Answer Section (Variable) ← CLAVE     │
├────────────────────────────────────────┤
│ NAME      │ "itla.edu.do"              │
│ TYPE      │ A (IPv4)                   │
│ CLASS     │ IN                         │
│ TTL       │ Time To Live (3600 seg)    │
│ RDLENGTH  │ 4 (bytes)                  │
│ RDATA     │ 192.168.50.10 ← RESPUESTA  │
└────────────────────────────────────────┘

La parte RDATA es lo que el atacante falsifica
```

---

## 💥 DNS Spoofing: La Técnica

### En Qué Consiste

El atacante intercepta una consulta DNS legítima y **responde ANTES que el servidor DNS real**, inyectando una dirección IP falsa.

### Requisitos Técnicos

```
Para realizar DNS Spoofing exitoso:

1. MITM Position ← ARP SPOOFING
   ├─ Necesario: Interceptar tráfico
   ├─ Mecanismo: ARP spoofing del gateway
   └─ Resultado: Atacante está en la ruta del tráfico

2. Escucha de Puerto 53 UDP
   ├─ Necesario: "Oír" consultas DNS
   ├─ Mecanismo: Socket raw UDP:53
   └─ Tool: Bettercap lo hace automáticamente

3. Respuesta Rápida
   ├─ Necesario: Responder ANTES que DNS legítimo
   ├─ Timing: <100ms (típicamente 50ms)
   └─ Ventaja: Atacante está en LAN, DNS en internet

4. Respuesta Bien Formada
   ├─ Necesario: Estructura DNS válida
   ├─ Campos: ID, flags, respuesta correcta
   └─ Verificación: Cliente valida respuesta
```

### Ventaja del Atacante: La Batalla por Respuesta

```
Competencia por velocidad:

Usuario hace query: "www.itla.edu.do"
       ↓ Por UDP (sin garantía de ordenamiento)
       
Ambas respuestas viajan:
├─ Respuesta Atacante:
│  └─ Distancia: ~10 metros (mismo switch)
│  └─ Latencia: ~1ms
│  └─ LLEGA PRIMERO ✓
│
└─ Respuesta DNS Legítimo:
   └─ Distancia: Potencialmente miles de km via internet
   └─ Latencia: 50-200ms
   └─ LLEGA TARDE (cliente ya aceptó respuesta del atacante)

Cliente DNS: "Primera respuesta válida = confiable"
             → Acepta respuesta del atacante
             → Desecha respuesta legítima como duplicado
```

---

## 🎯 Flujo Completo: ARP Spoofing → DNS Spoofing

### Fase 1: ARP Spoofing Setup

```
┌─────────────────────────────────────────────────┐
│ ARP SPOOFING INITIALIZATION                     │
├─────────────────────────────────────────────────┤
│                                                 │
│ Bettercap comienza a enviar ARP replies falsas │
│                                                 │
│ Usuario:      "¿MAC del gateway 192.168.1.1?" │
│ Response:     "Soy yo! MAC: aa:bb:cc:dd:ee:ff"  │
│ (Viene de)    Atacante (no es el gateway)       │
│                                                 │
│ Gateway:      "¿MAC del usuario 192.168.1.50?" │
│ Response:     "Soy yo! MAC: aa:bb:cc:dd:ee:ff"  │
│ (Viene de)    Atacante (no es el usuario)       │
│                                                 │
│ Resultado:    usuario ↔ atacante ↔ gateway     │
│               (todos piensan hablar con otro) │
│                                                 │
└─────────────────────────────────────────────────┘

Tablas ARP comprometidas:
┌─────────────────────────────┐
│ Usuario:                    │
│ 192.168.1.1 = aa:bb:cc:... │ (falso)
│ 192.168.1.100 = aa:bb:cc...│ (atacante)
│                             │
│ Gateway:                    │
│ 192.168.1.50 = aa:bb:cc:...│ (falso)
│ Envía todo a atacante       │
│                             │
│ Atacante:                   │
│ Posición MITM establecida ✓ │
└─────────────────────────────┘
```

### Fase 2: Captura de DNS Queries

```
Usuario consulta DNS (Puerto UDP 53):

Socket UDP vacío:
┌──────────────────────────────────────────┐
│ Source IP: 192.168.1.50 (Usuario)        │
│ Dest IP: 8.8.8.8 (Google DNS)            │
│ Port: 53 (DNS)                           │
│                                          │
│ Payload DNS:                             │
│ ├─ QNAME: itla.edu.do                   │
│ ├─ QTYPE: A (IPv4)                      │
│ ├─ QCLASS: IN (Internet)                │
│ └─ ID: 0x1234 (Transaction ID)          │
├──────────────────────────────────────────┤
│ Paquete capturado por:                   │
│ Bettercap en puerto 53 del atacante      │
│                                          │
│ Lectura: Usuario quiere IP de itla.      │
└──────────────────────────────────────────┘
```

### Fase 3: Inyección de Respuesta Falsa

```
Bettercap construye respuesta DNS falsa:

Paquete DNS Response Crafteado:
┌──────────────────────────────────────────┐
│ DNS Header:                               │
│ ├─ ID: 0x1234 (MISMO ID del query)       │
│ ├─ QR: 1 (Response, no Query)            │
│ ├─ AA: 1 (Authoritative Answer)          │
│ ├─ RCODE: 0 (No error)                   │
│ └─ QDCOUNT: 1, ANCOUNT: 1                │
│                                          │
│ Question Section:                        │
│ ├─ QNAME: itla.edu.do                   │
│ ├─ QTYPE: A                              │
│ └─ QCLASS: IN                            │
│                                          │
│ Answer Section (LA FALSIFICACIÓN):       │
│ ├─ NAME: itla.edu.do                    │
│ ├─ TYPE: A                               │
│ ├─ TTL: 3600 (parece legítimo)          │
│ ├─ RDLENGTH: 4                           │
│ └─ RDATA: 192.168.1.100 ← MALICIOSO    │
│            (Servidor atacante)           │
└──────────────────────────────────────────┘

Enviado desde: Atacante (aa:bb:cc:dd:ee:ff)
Destino: Usuario (192.168.1.50)
Velocidad: ~1ms (llega primero)
```

### Fase 4: Aceptación y Cacheo

```
Cliente DNS del usuario recibe:

Validación:
├─ ¿ID correcto? SÍ (0x1234) ✓
├─ ¿Formato válido? SÍ ✓
├─ ¿Autoridad legítima? SÍ (dice ser autoritativa) ✓
├─ ¿Viene de DNS conocido? NO (pero es UDP, puede venir de cualquiera)
│                          ✗ AQUÍ ESTÁ LA VULNERABILIDAD
└─ Conclusión: Aceptada como válida

Cacheo:
┌──────────────────────────────┐
│ DNS Cache Local (Usuario)    │
├──────────────────────────────┤
│ itla.edu.do → 192.168.1.100 │ ← Falso
│ TTL: 3600 segundos (1 hora) │
│ Válido durante 1 hora        │
└──────────────────────────────┘

Resultado:
Todas las consultas a itla.edu.do en la próxima hora
retornarán la IP maliciosa.
```

### Fase 5: Explotación

```
Usuario cierra navegador y lo vuelve a abrir:

1. Escribe: www.itla.edu.do
   └─ Cliente revisa caché: ✓ Encontrada
   └─ Retorna: 192.168.1.100 (atacante)
   
2. Navegador intenta conectar a 192.168.1.100
   
3. Servidor malicioso del atacante responde
   
4. Página suplantada cargada:
   ├─ Identical al sitio real de ITLA
   ├─ Formulario de login (phishing)
   └─ Usuario ingresa credenciales
      └─ COMPROMETIDAS ✗

IMPACTO: Credenciales robadas sin que usuario
         note que algo está mal
```

---

## 📊 Variantes del Ataque DNS

### Variante 1: DNS Spoofing Simple (Este Repo)

```
┌──────────────────────────┐
│ DNS Spoofing Simple      │
├──────────────────────────┤
│ Mecanismo: Inyectar      │
│ respuesta DNS falsa      │
│                          │
│ Requisito: MITM (ARP)    │
│                          │
│ Duración: Mientras       │
│ está en caché (TTL)      │
│                          │
│ Afecta: Solo MÁQUINAs    │
│ víctima directa          │
│                          │
│ Complejidad: BAJA        │
└──────────────────────────┘
```

### Variante 2: DNS Cache Poisoning

```
┌──────────────────────────────────┐
│ DNS Cache Poisoning              │
├──────────────────────────────────┤
│ Mecanismo: Corromper caché del   │
│ servidor DNS recursivo           │
│                                  │
│ Requisito: Predicción de Query ID│
│            Puerto UDP fuente      │
│ (Más difícil que L2 spoofing)    │
│                                  │
│ Duración: Largo plazo (horas/días│
│ después que TTL expire, si se    │
│ re-consulta)                     │
│                                  │
│ Afecta: MUCHS máquinas           │
│ (todas que usan ese DNS)         │
│                                  │
│ Complejidad: MEDIA - ALTA        │
│ (Requiere fuerza bruta de ID)    │
└──────────────────────────────────┘
```

### Variante 3: DNSSEC Bypass (Avanzado)

```
┌────────────────────────────────┐
│ DNSSEC Bypass                  │
├────────────────────────────────┤
│ Mecanismo: Forjar respuestas   │
│ DNS con firmas criptográficas  │
│ válidas                        │
│                                │
│ Requisito: Poseer clave privada│
│ o ejecutar man-in-the-middle   │
│ antes de validación DNSSEC     │
│                                │
│ Nota: Casi imposible sin       │
│ acceso a sistemas de DNS       │
└────────────────────────────────┘
```

---

## 🔐 Por Qué Funciona: Vulnerabilidades Base

### 1. Protocolo UDP sin Autenticación

```
DNS originalmente (1987) asumía:
✗ Red cerrada y confiable
✗ No podría haber atacantes en la red local
✗ UDP es suficientemente rápido para detectar falsos

Realidad actual (2024):
✓ Redes WiFi públicas
✓ Redes corporativas comprometidas
✓ Atacantes con posición MITM fácil
✓ UDP ciego a origen real (sin verificación)
```

### 2. Falta de Autenticación del Servidor

```
Consulta DNS:
┌─────────────────┐
│ ¿Quién eres?    │ Cliente
└─────────────────┘
         ↓
Respuesta:
┌──────────────────┐
│ Soy 8.8.8.8      │ Atacante (FALSO)
└──────────────────┘

Cliente acepta porque:
├─ No hay firma digital
├─ No hay certificado
├─ No hay HMAC/autenticación
└─ Solo confía en la estructura del paquete DNS

Solución: DNSSEC (firmas criptográficas)
```

### 3. TTL Largo (Almacenamiento en Caché)

```
Respuesta con TTL: 3600 segundos

Significado:
"Creo este resultado durante 1 hora"

Problema:
Si la respuesta es falsa,
queda almacenada en caché durante 1 hora

Ventaja para atacante:
No necesita mantener ataque activo indefinidamente
Solo 1 respuesta falsa = 3600 segundos de impacto
```

### 4. Validación Débil de Respuesta

```
Cliente DNS valida:
├─ ¿El Transaction ID coincide?
├─ ¿Es una respuesta (no query)?
├─ ¿El formato está bien formado?
├─ ¿Viene de un servidor DNS conocido?
│   └─ NO VALIDA ESTO (en UDP sin criptografía)
└─ Si todo lo anterior es sí → Aceptada

Fallo de seguridad:
La "validación de servidor" es trivial de saltar
porque no hay mecanismo anti-spoofing en UDP
```

---

## 🛡️ Controles de Detección

### Indicadores de Ataque

```
1. Cambio de IP de Dominio Conocido
   Ej: itla.edu.do antes: 192.168.50.10
                   ahora: 192.168.1.100
   
2. Respuesta DNS desde múltiples servidores
   User resolve itla.edu.do →
   Respuesta 1: 192.168.50.10 (real, lenta)
   Respuesta 2: 192.168.1.100 (falsa, rápida)
   ← Cliente aceptó la falsa

3. TTL Extraño (muy bajo o muy alto)
   Ej: 3600 (1 hora) en lugar del TTL real
   
4. Cambio repentino de TTL
   Ej: Antes 5 minutos, ahora 3600 segundos
   
5. Tráfico ARP anómalo
   Múltiples ARP replies de misma MAC
   para diferentes IPs (ARP spoofing)
```

---

## 📈 Escala de Impacto

```
DNS Spoofing Simple (MITM):
├─ Usuarios afectados: 1-10 (solo en ataque activo)
├─ Duración: Minutos a horas (mientras MAN attack)
├─ Necesidad de esfuerzo: Bajo (Bettercap automatizado)
├─ Reversibilidad: Inmediata (limpia caché)
└─ Riesgo: 🟡 Medio-Alto

DNS Poisoning (Cache):
├─ Usuarios afectados: 50-500 (todos que usan DNS)
├─ Duración: Horas a días (TTL + requery ciclo)
├─ Necesidad de esfuerzo: Medio (predicción de ID)
├─ Reversibilidad: Lenta (esperar expiración TTL)
└─ Riesgo: 🔴 Crítica

Cascada de Ataque:
├─ DNS spoofing → Phishing
├─ Phishing → Credenciales robadas
├─ Credenciales → Acceso a sistemas
└─ Total: 🔴 CRÍTICA
```

---

## Conclusiones Técnicas

1. **DNS es inseguro por diseño**: UDP sin autenticación
2. **ARP spoofing es requisito**: Necesario estar en ruta del tráfico
3. **Velocidad es ventaja**: Atacante siempre llega primero en LAN
4. **TTL es aliado del atacante**: Cacheo prolonga el impacto
5. **Validación débil**: No hay verificación del servidor origen
6. **DNSSEC es defensa requerida**: Firmas criptográficas de respuestas

---

**Última actualización**: Febrero 2026
