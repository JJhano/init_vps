# Configuración VPS - Ubuntu 24.04

Scripts para configuración inicial y segura de un VPS con Ubuntu 24.04.

## 🚀 Inicio Rápido

### 1. Configurar variables

```bash
# Copiar el archivo de ejemplo
cp .env.basic.example .env

# Editar con tus valores
nano .env
```

**Variables importantes a configurar:**
- `SSH_ADMIN_KEYS`: Tu llave SSH pública
- `FAIL2BAN_WHITELIST`: Tu IP pública actual
- `SSH_PORT`: Puerto SSH (opcional, por defecto 22)

### 2. Ejecutar configuración básica

```bash
# Hacer ejecutable el script
chmod +x run_basic.sh

# Ejecutar como root
sudo ./run_basic.sh
```

## 📋 Scripts Incluidos

### Configuración Básica (run_basic.sh)

1. **01_update.sh** - Actualización del sistema
2. **02_ssh.sh** - Configuración SSH con llaves
3. **03_ufw.sh** - Configuración del firewall
4. **04_fail2ban.sh** - Protección contra ataques de fuerza bruta
5. **05_docker.sh** - Instalación de Docker (opcional)

## 🔧 Características de Ubuntu 24.04

### Socket Activation
Ubuntu 24.04 usa **systemd socket activation** por defecto para SSH. Si cambias el puerto SSH del 22, el script automáticamente:
- Deshabilita `ssh.socket`
- Habilita `ssh.service` tradicional
- Configura el puerto correcto

### Servicios
- SSH: `ssh.service` (no `sshd.service`)
- Logs: `journalctl -u ssh`

## 🛡️ Seguridad

### Recomendaciones

1. **Antes de ejecutar:**
   - Agrega tu llave SSH pública
   - Agrega tu IP a la whitelist de Fail2ban
   - No cambies el puerto SSH en la primera ejecución

2. **Después de ejecutar:**
   - Prueba la conexión SSH en otra terminal
   - Verifica el firewall: `sudo ufw status`
   - Revisa Fail2ban: `sudo fail2ban-client status`

### Oracle Cloud

Si usas Oracle Cloud, también debes:
1. Abrir el puerto SSH en **Security List**
2. Configurar **iptables** si es necesario:
   ```bash
   sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport TU_PUERTO -j ACCEPT
   ```

## 📖 Uso de Scripts Individuales

```bash
# Actualizar sistema
sudo ./scripts/01_update.sh

# Configurar SSH
sudo ./scripts/02_ssh.sh

# Configurar firewall
sudo ./scripts/03_ufw.sh

# Configurar Fail2ban
sudo ./scripts/04_fail2ban.sh

# Instalar Docker
sudo ./scripts/05_docker.sh
```

## ⚠️ Troubleshooting

### SSH no conecta después de cambiar puerto

```bash
# Verificar que SSH escucha en el puerto correcto
sudo ss -tlnp | grep ssh

# Ver logs
sudo journalctl -u ssh -n 50

# Deshabilitar socket manualmente
sudo systemctl stop ssh.socket
sudo systemctl disable ssh.socket
sudo systemctl restart ssh.service
```

### Connection timeout

- Verifica la Security List en tu proveedor cloud
- Verifica UFW: `sudo ufw status`
- Verifica iptables: `sudo iptables -L -n`

### No puedo conectar con mi llave SSH

```bash
# Verificar permisos
ls -la ~/.ssh/
# authorized_keys debe ser 600
# .ssh debe ser 700

# Ver logs de autenticación
sudo tail -f /var/log/auth.log
```

## 📝 Notas

- Todos los scripts crean backups antes de modificar archivos
- Los logs están en `/var/log/`
- La configuración SSH original está en `/etc/ssh/sshd_config.backup`

## 🔗 Enlaces Útiles

- [Docker Docs](https://docs.docker.com/)
- [UFW Docs](https://help.ubuntu.com/community/UFW)
- [Fail2ban Wiki](https://www.fail2ban.org/)
- [OpenSSH Config](https://www.ssh.com/academy/ssh/sshd_config)
