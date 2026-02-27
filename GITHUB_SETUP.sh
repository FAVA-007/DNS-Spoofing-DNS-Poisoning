# Instrucciones para Subir a GitHub

## Paso 1: Inicializar el Repositorio Local

```bash
# Navegar a la carpeta del proyecto
cd "c:\Users\FAVA\Desktop\Practica 4 S.R\DNS-Spoofing-DNS-Poisoning"

# Inicializar repositorio git
git init

# Verificar que se creó .git
ls -la
# Deberías ver: drwxr-xr-x  .git
```

## Paso 2: Configurar Git (Primera vez)

```bash
# Configurar nombre de usuario
git config --global user.name "FAVA-007"

# Configurar email
git config --global user.email "tu_email@itla.edu.do"

# Verificar configuración
git config --global --list
```

## Paso 3: Agregar Archivos al Staging

```bash
# Agregar todos los archivos
git add .

# Verificar qué archivos se agregarán
git status
# Deberías ver archivos en verde (staged)
```

## Paso 4: Crear Commit

```bash
# Crear commit inicial
git commit -m "Inicial: Documentación completa de DNS Spoofing/Poisoning

- README.md con descripción del protocolo DNS
- GUIA_DE_USO.md con instrucciones prácticas usando Bettercap
- EXPLICACION_TECNICA.md con análisis profundo de spoofing
- MITIGACION.md con defensa mediante DNSSEC y DHCP Snooping
- Estructura de carpetas para evidencia fotográfica
- Configuraciones de referencia para laboratorio"
```

## Paso 5: Agregar Repositorio Remoto (GitHub)

```bash
# Agregar remoto (reemplazar URL con tu repositorio real)
git remote add origin https://github.com/FAVA-007/DNS-Spoofing-DNS-Poisoning.git

# Verificar remoto
git remote -v
# Deberías ver:
# origin  https://github.com/FAVA-007/DNS-Spoofing-DNS-Poisoning.git (fetch)
# origin  https://github.com/FAVA-007/DNS-Spoofing-DNS-Poisoning.git (push)
```

## Paso 6: Subir a GitHub

```bash
# Si la rama por defecto es "main"
git push -u origin main

# Si prefieres usar "master"
git branch -M main
git push -u origin main
```

## Paso 7: Agregar Imágenes Posteriormente

Una vez que tomes los screenshots del ataque:

```bash
# 1. Guardar imágenes en carpeta imagenes/
cp /ruta/screenshot_bettercap.png imagenes/image_bettercap_setup.png
cp /ruta/screenshot_wireshark_dns.png imagenes/image_dns_spoofing_wireshark.png
cp /ruta/screenshot_phishing.png imagenes/image_phishing_page.png
cp /ruta/screenshot_flow.png imagenes/image_network_flow.png

# 2. Agregar cambios
git add imagenes/

# 3. Commit
git commit -m "Agregar evidencia fotográfica: ejecución del ataque DNS

- image_bettercap_setup.png: Configuración inicial Bettercap
- image_dns_spoofing_wireshark.png: Captura de DNS falso
- image_phishing_page.png: Página de phishing suplantada
- image_network_flow.png: Diagrama del flujo de ataque"

# 4. Push
git push origin main
```

## Verificación Final

Visita: https://github.com/FAVA-007/DNS-Spoofing-DNS-Poisoning

Deberías ver:
- ✅ README.md visible en la página principal
- ✅ Carpeta imagenes/ (vacía por ahora)
- ✅ Archivos de guía y documentación
- ✅ Historial de commits

---

**Última actualización**: Febrero 2026
