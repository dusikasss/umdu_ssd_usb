# Инструкция по запуску системы с внешнего  USB диска

1. Запишите образ ОС c Home Assistant, поставляемый в комплекте на внешний USB диск - скачать

2. Подключите внешний диск в USB порт

2. Подключитесь к серверу по SSH

2. Выполните команду и следуйте инструкциям: 
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