# Инструкция по установке

## Шаги установки

1. Подключитесь к серверу по SSH

2. Выполните команду:
   ```
   curl -O https://raw.githubusercontent.com/dusikasss/umdu_ssd_usb/main/install_to_usb.sh && chmod +x install_to_usb.sh && sudo ./install_to_usb.sh
   ```

3. Выполните команду:
   ```
   systemctl enable armbian-resize-filesystem.service
   ```

4. Выполните команду:
   ```
   reboot
   ```