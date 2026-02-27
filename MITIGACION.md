# MITIGACIÓN: Defensa contra DNS Spoofing y Poisoning

## 🛡️ Estrategia de Defensa Multicapas

La defensa contra ataques DNS requiere múltiples niveles, desde criptografía hasta monitoreo activo.

---

## 1️⃣ Nivel Crítico: Implementación de DNSSEC

### ¿Qué es DNSSEC?

DNSSEC (Domain Name System Security Extensions) añade autenticación criptográfica a DNS mediante:
- Firmas digitales en respuestas DNS
- Validación de integridad de datos
- Protección contra suplantación

### Cómo funciona DNSSEC

```
Sin DNSSEC:
Client → "¿itla.edu.do?" → DNS → Response (sin firma)
Client → Acepta ciegamente ✗

Con DNSSEC:
Client → "¿itla.edu.do?" → DNS → Response + SIGNATURE
Client → Valida firma con DNSKEY
         ├─ ¿Firma válida? SÍ → Aceptar ✓
         └─ ¿Firma válida? NO → Rechazar ✗
```

### Implementación en Server DNS (BIND/PowerDNS)

#### Para ITLA (Administrador del dominio):

```bash
# 1. Generar claves DNSSEC
dnssec-keygen -a RSASHA256 -b 2048 -f KSK itla.edu.do  # KSK
dnssec-keygen -a RSASHA256 -b 1024 -f ZSK itla.edu.do  # ZSK

# Resultado:
# Kitla.edu.do.+008+xxxxx.key (KSK)
# Kitla.edu.do.+008+yyyyy.key (ZSK)

# 2. Firmar la zona
dnssec-signzone -k Kitla.edu.do.+008+xxxxx.key \
                itla.edu.do.zone \
                Kitla.edu.do.+008+yyyyy.key

# Resultado: itla.edu.do.zone.signed

# 3. Configurar BIND para usar zona firmada
# En /etc/bind/named.conf.local:
zone "itla.edu.do" {
    type master;
    file "/etc/bind/zones/itla.edu.do.zone.signed";
    allow-update { none; };
};

# 4. Recargar BIND
sudo rndc reload

# 5. Verificar DNSSEC
dig itla.edu.do DNSKEY
dig itla.edu.do A +dnssec
# Debería mostrar: "ad" flag (authenticated data)
```

### Validación DNSSEC en Cliente

```bash
# En máquina cliente (Linux)

# Verificar si están habilitadas validaciones
grep "dnssec-validation" /etc/named.conf
# Resultado esperado: dnssec-validation auto;

# O en resolvconf:
cat /etc/resolv.conf
nameserver 8.8.8.8  # Google DNS (soporta DNSSEC)

# Validar respuesta
dig itla.edu.do +dnssec

; <<>> DiG 9.11.3 <<>> itla.edu.do +dnssec
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 12345
;; flags: qr rd ra ad;
;           ^
;           Authenticated Data flag ✓

itla.edu.do.        3600    IN    A    192.168.50.10
itla.edu.do.        3600    IN    RRSIG    A 8 3 3600 ...
```

### Validación en Windows

```powershell
# En PowerShell (Windows 10+)

# Habilitar validación DNSSEC
Set-DnsClientDohServerAddress -ServerAddress 8.8.8.8 `
                              -AllowFallbackToUdp $False `
                              -AllowFallbackToTcp $False

# O usar GUI:
# Settings → Network → DNS settings → DNSSEC validation: ON
```

---

## 2️⃣ Nivel Red Local: DHCP Snooping

### ¿Qué es DHCP Snooping?

DHCP Snooping es una defensa en capa 2 que valida solicitudes DHCP y previene ataques que implican falsificación de direcciones.

### Implementación en Switch Cisco

```cisco
! Habilitar DHCP Snooping
Switch(config)# ip dhcp snooping
Switch(config)# ip dhcp snooping vlan 10,20,30

! Designar puerto de confianza (donde está el servidor DHCP)
Switch(config)# interface GigabitEthernet0/0/1
Switch(config-if)# ip dhcp snooping trust
Switch(config-if)# exit

! Puerto de usuario: NO confiable
Switch(config)# interface range GigabitEthernet0/0/2-24
Switch(config-if-range)# no ip dhcp snooping trust
Switch(config-if-range)# ip dhcp snooping limit rate 10
Switch(config-if-range)# exit

! Habilitar DAI (Dynamic ARP Inspection)
Switch(config)# ip arp inspection vlan 10,20,30

! Puerto de confianza para DAI
Switch(config)# interface GigabitEthernet0/0/1
Switch(config-if)# ip arp inspection trust
Switch(config-if)# exit

! Verificar configuración
Switch# show ip dhcp snooping
DHCP snooping is ON
DHCP snooping is enabled on vlans: 10,20,30
```

### Impacto en Defensa

```
ARP Spoofing sin DAI:
Atacante → Envía ARP reply falso
Switch → Propaga a todos
Usuario → Tabla ARP comprometida ✗

ARP Spoofing con DAI:
Atacante → Envía ARP reply falso
Switch → Consulta BD de DHCP bindings
         ├─ ¿IP-MAC combinación válida?
         ├─ SÍ → Propagar ✓
         └─ NO → Bloquear ✗

Resultado: ARP spoofing bloqueado,
           DNS spoofing imposible de realizar
```

---

## 3️⃣ Defensas DNS Locales

### Validación en Resolver (DNSSEC-Aware Resolver)

```bash
# Instalación de validador DNSSEC local
sudo apt install -y unbound

# Configurar /etc/unbound/unbound.conf
server:
    module-config: "validator iterator"
    auto-trust-anchor-file: "/var/lib/unbound/root.key"
    
    # Habilitar DNSSEC
    enable-systemd: yes
    module-config: "iterator"
    
    # Validación DNSSEC
    trust-anchor-file: "/var/lib/unbound/root.key"
    auto-trust-anchor-file: "/var/lib/unbound/root.key"

# Iniciar Unbound
sudo systemctl restart unbound

# Verificar
dig @localhost itla.edu.do +dnssec
# Debería mostrar "ad" flag si respuesta es validada
```

### Configuración de RPZ (Response Policy Zone)

RPZ permite bloquear respuestas DNS maliciosas en el servidor:

```
# /etc/bind/rpz.db
$TTL 60
@   IN  SOA ns1.example.com. admin.example.com. (
        2024022600
        3600
        600
        604800
        60)
    IN  NS  ns1.example.com.

; Bloquear IP maliciosa
192.168.1.100 CNAME rpz-drop.

; En named.conf:
rpz-response-policy zone "rpz.db" log;
```

---

## 4️⃣ Defensas a Nivel Red

### Segmentación de Red (VLANs + ACLs)

```cisco
! Aislar servidor DNS
! Solo permitir tráfico DNS desde hosts autorizados

# ACL para DNS
Switch(config)# ip access-list extended DNS_POLICY
Switch(config-acl)# permit udp any host 8.8.8.8 eq 53
Switch(config-acl)# permit tcp any host 8.8.8.8 eq 53
Switch(config-acl)# deny udp any any eq 53
Switch(config-acl)# deny tcp any any eq 53
Switch(config-acl)# permit ip any any

# Aplicar a puerto user
Switch(config)# interface GigabitEthernet0/0/1
Switch(config-if)# ip access-group DNS_POLICY out
```

### Proxy DNS (Intermediario de Confianza)

```
Topología sin Proxy:
User → Internet DNS (vulnerable a spoofing)

Topología con Proxy:
User → Local DNS Proxy → Internet DNS
       (Validado DNSSEC)  (Confiable)

Implementación:
sudo apt install dnsmasq

/etc/dnsmasq.conf:
# Reenviar a Google DNS (con DNSSEC)
server=8.8.8.8
server=8.8.4.4

# Habilitar DNSSEC
dnssec

# Escuchar en interfaz local
interface=eth0
listen-address=192.168.1.1
```

---

## 5️⃣ Monitoreo y Detección de Anomalías

### Script de Monitoreo DNS

```bash
#!/bin/bash
# monitor_dns_spoofing.sh

TARGET_DOMAIN="itla.edu.do"
EXPECTED_IP="192.168.50.10"
LOG_FILE="/var/log/dns_monitor.log"

while true; do
    # Resolver dominio
    RESOLVED_IP=$(dig +short $TARGET_DOMAIN @8.8.8.8)
    
    # Comparar con IP esperada
    if [ "$RESOLVED_IP" != "$EXPECTED_IP" ]; then
        echo "[ALERTA] DNS Spoofing detectado!" >> $LOG_FILE
        echo "  Dominio: $TARGET_DOMAIN" >> $LOG_FILE
        echo "  IP esperada: $EXPECTED_IP" >> $LOG_FILE
        echo "  IP resuelta: $RESOLVED_IP" >> $LOG_FILE
        echo "  Timestamp: $(date)" >> $LOG_FILE
        
        # Enviar alerta
        mail -s "ALERTAS: Posible DNS Spoofing de $TARGET_DOMAIN" \
             admin@itla.edu.do < $LOG_FILE
    fi
    
    sleep 300  # Verificar cada 5 minutos
done
```

### Alertas en Wireshark

```
Crear filtros de detección:

1. Respuestas DNS de múltiples servidores:
   dns && dns.flags.response == 1

2. Cambios de TTL sospechosos:
   dns && dns.ttl < 300

3. Respuestas de Puertos altos (no 53):
   dns && tcp.srcport > 1024

4. Múltiples respuestas para mismo query:
   dns && dns.id == 0x1234
```

---

## 6️⃣ Checklist de Implementación

```
[ ] 1. DNSSEC Fundamentales
       [ ] Generar claves (KSK, ZSK)
       [ ] Firmar zona DNS
       [ ] Publicar DNSKEY
       [ ] Configurar DS en .do registry
       [ ] Validar con dig +dnssec

[ ] 2. DHCP Snooping
       [ ] Habilitar en switch
       [ ] Designar puertos confiables
       [ ] Limitar rate de peticiones
       [ ] Habilitar DAI
       [ ] Configurar validación de bindings

[ ] 3. Resolvers Seguros
       [ ] Validador DNSSEC local (Unbound)
       [ ] Proxy DNS (dnsmasq)
       [ ] RPZ para blocked hosts
       [ ] Logging centralizado

[ ] 4. Red y ACLs
       [ ] ACLs de puerto 53
       [ ] Segmentación de DNS
       [ ] Whitelist de servidores DNS
       [ ] Bloquear DNS externo (forzar local)

[ ] 5. Monitoreo
       [ ] Alert de cambio de IP
       [ ] Monitoreo de DNSSEC validation
       [ ] Logs centralizados (SIEM)
       [ ] Alertas en tiempo real

[ ] 6. Capacitación
       [ ] Educar usuarios sobre phishing
       [ ] Alertar sobre certificados HTTPS
       [ ] Procedimientos de reporte
       [ ] Simulacros de phishing
```

---

## 7️⃣ Procedimiento de Respuesta a Incidente

```
SI se detecta DNS Spoofing:

INMEDIATO (0-5 minutos):
├─ Aislar sistemas afectados de la red
├─ Bloquear tráfico de/hacia IPs maliciosas
├─ Notificar a usuarios que no hagan click en links

CORTO PLAZO (5-30 minutos):
├─ Capturar tráfico PCAP para análisis
├─ Revisar logs de acceso (¿Qué credenciales bloqueadas?)
├─ Análisis forense de máquinas víctima
├─ Flush de caché DNS en todos los hosts

MEDIO PLAZO (1-2 horas):
├─ Análisis completo del PCAP
├─ Determinar qué información fue comprometida
├─ Implementar parches de seguridad
├─ Cambiar credenciales que fueron expuestas
├─ Validar integridad de sistemas

LARGO PLAZO (próximas semanas):
├─ Post-mortem del incidente
├─ Mejorar defensas (DNSSEC, DHCP Snooping)
├─ Auditoría de seguridad DNS
├─ Capacitación de personal
├─ Actualizar políticas
```

---

## 🔐 Configuración Segura de Referencia

### ITLA: Implementación Completa

```bash
# ==================== SERVIDOR DNS ====================

# 1. DNSSEC Signing
dnssec-keygen -a RSASHA256 -b 2048 -f KSK itla.edu.do
dnssec-keygen -a RSASHA256 -b 1024 itla.edu.do
dnssec-signzone -S itla.edu.do.zone

# 2. BIND Secure Configuration
cat > /etc/bind/named.conf.options << 'EOF'
acl "trusted" {
    192.168.0.0/16;
    127.0.0.1;
};

options {
    directory "/var/cache/bind";
    dnssec-validation auto;
    dnssec-lookaside auto;
    
    querylog yes;
    
    # Limitar recursión
    allow-recursion { trusted; };
    
    # Habilitar rate limiting
    rate-limit {
        responses-per-second 5;
        errors-per-second 5;
    };
};
EOF

# 3. Logs de auditoría
cat > /etc/bind/named.conf.logging << 'EOF'
logging {
    channel audit_log {
        file "/var/log/bind/audit.log" versions 3 size 100m;
        severity debug;
        print-time yes;
        print-severity yes;
    };
    category queries { audit_log; };
    category security { audit_log; };
};
EOF

# ==================== SWITCH CORE ====================

# DHCP Snooping
ip dhcp snooping
ip dhcp snooping vlan 1,10,20,30

# DAI
ip arp inspection vlan 1,10,20,30

# Trust ports
interface Gi0/0/1
  ip dhcp snooping trust
  ip arp inspection trust

# User ports
interface range Gi0/0/2-24
  no ip dhcp snooping trust
  no ip arp inspection trust

# ==================== CLIENTE (RESOLV) ====================

# Usar validador DNSSEC local
nameserver 127.0.0.1  # Unbound local
options trust-ad no-tls-1.2

# Validar DNSSEC
dig itla.edu.do +dnssec
# Resultado: "ad" flag presente
```

---

**Última actualización**: Febrero 2026  
**Recomendación**: DNSSEC es OBLIGATORIO para dominios críticos. Implementar sin demora.
