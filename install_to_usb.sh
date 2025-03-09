#!/bin/bash

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
  echo "Ошибка: Этот скрипт должен быть запущен от имени root"
  exit 1
fi

echo "ВНИМАНИЕ: Убедитесь, что USB диск подключен к устройству перед продолжением."
read -p "Нажмите Enter для продолжения..."

# 1. Копирование необходимых файлов с репозитория GitHub
echo "Шаг 1: Загрузка файлов с репозитория GitHub"
TMP_DIR="/tmp/umdu_ssd_usb"
mkdir -p "$TMP_DIR"

# Проверка наличия curl
if ! command -v curl &> /dev/null; then
  echo "Устанавливаем curl..."
  apt-get update
  apt-get install -y curl || {
    echo "Ошибка: Не удалось установить curl"
    exit 1
  }
fi

# Загрузка архива с репозитория
echo "Загрузка архива с репозитория..."
REPO_URL="https://github.com/dusikasss/umdu_ssd_usb/archive/refs/heads/main.zip"
ZIP_FILE="$TMP_DIR/repo.zip"

curl -L "$REPO_URL" -o "$ZIP_FILE" || {
  echo "Ошибка: Не удалось скачать архив с репозитория"
  exit 1
}

# Проверка наличия unzip
if ! command -v unzip &> /dev/null; then
  echo "Устанавливаем unzip..."
  apt-get update
  apt-get install -y unzip || {
    echo "Ошибка: Не удалось установить unzip"
    exit 1
  }
fi

# Распаковка архива
echo "Распаковка архива..."
unzip -o "$ZIP_FILE" -d "$TMP_DIR" || {
  echo "Ошибка: Не удалось распаковать архив"
  exit 1
}

# Определяем имя распакованной директории
EXTRACT_DIR=$(find "$TMP_DIR" -type d -name "umdu_ssd_usb-*" | head -n 1)

if [ -z "$EXTRACT_DIR" ]; then
  echo "Ошибка: Не удалось найти распакованную директорию"
  exit 1
fi

# 2. Проверка подключенных дисков
echo "Шаг 2: Проверка подключенных дисков"
lsblk
if ! lsblk | grep -q "sd[a-z]"; then
  echo "Ошибка: USB диск не обнаружен. Подключите диск и запустите скрипт снова."
  exit 1
fi

# Определение USB диска (предположительно sda)
USB_DISK=""
if lsblk | grep -q "sda"; then
  USB_DISK="sda"
else
  # Если sda не найден, попробуем найти другой sd* диск
  USB_DISK=$(lsblk | grep "sd[a-z]" | head -n 1 | awk '{print $1}')
  if [ -z "$USB_DISK" ]; then
    echo "Ошибка: Невозможно определить USB диск"
    exit 1
  fi
fi

echo "Обнаружен USB диск: /dev/$USB_DISK"

# 3. Монтирование диска
echo "Шаг 3: Монтирование USB диска"
MOUNT_POINT="/mnt/$USB_DISK"
mkdir -p "$MOUNT_POINT"

# Размонтировать, если уже смонтирован
umount "$MOUNT_POINT" 2>/dev/null

# Монтирование диска
mount "/dev/${USB_DISK}1" "$MOUNT_POINT" || {
  echo "Ошибка: Не удалось смонтировать раздел /dev/${USB_DISK}1"
  echo "Попытка монтирования /dev/$USB_DISK..."
  mount "/dev/$USB_DISK" "$MOUNT_POINT" || {
    echo "Ошибка: Не удалось смонтировать USB диск"
    exit 1
  }
}

# 4. Копирование файлов DTB
echo "Шаг 4: Копирование файлов DTB"
DTB_TARGET_DIR="$MOUNT_POINT/boot/dtb"
DTB_SOURCE_DIR="$EXTRACT_DIR/allwinner"

# Создаем директорию, если она не существует
mkdir -p "$DTB_TARGET_DIR"

# Копируем файлы
cp -r "$DTB_SOURCE_DIR" "$DTB_TARGET_DIR/" || {
  echo "Ошибка: Не удалось скопировать файлы DTB"
  umount "$MOUNT_POINT" 2>/dev/null
  exit 1
}

echo "Файлы DTB успешно скопированы"

# Редактирование файла armbianEnv.txt
ARMBIAN_ENV_FILE="$MOUNT_POINT/boot/armbianEnv.txt"
if [ -f "$ARMBIAN_ENV_FILE" ]; then
  echo "Модификация файла armbianEnv.txt..."
  
  # Проверяем, есть ли строка с overlays
  if grep -q "^overlays=" "$ARMBIAN_ENV_FILE"; then
    # Заменяем строку с overlays на новую с нужными значениями
    sed -i 's/^overlays=.*/overlays=ph-uart2 ph-uart5 usb0-host/' "$ARMBIAN_ENV_FILE"
    echo "Заменена строка overlays на 'overlays=ph-uart2 ph-uart5 usb0-host' в armbianEnv.txt"
  else
    # Если строки с overlays нет, добавляем ее
    echo "overlays=ph-uart2 ph-uart5 usb0-host" >> "$ARMBIAN_ENV_FILE"
    echo "Создана новая строка overlays в armbianEnv.txt"
  fi
else
  echo "Предупреждение: Файл armbianEnv.txt не найден"
fi

# 5. Установка U-Boot
echo "Шаг 5: Установка U-Boot"
cd "$EXTRACT_DIR/u-boot" || {
  echo "Ошибка: Директория с U-Boot не найдена"
  umount "$MOUNT_POINT" 2>/dev/null
  exit 1
}

# Установка mtd-tools, если необходимо
echo "Установка необходимых инструментов..."
apt-get update
apt-get install -y mtd-tools || {
  echo "Ошибка: Не удалось установить mtd-tools"
  umount "$MOUNT_POINT" 2>/dev/null
  exit 1
}

# Прошивка U-Boot
echo "Прошивка U-Boot..."
if [ -f "u-boot-sunxi-with-spl.bin" ]; then
  flashcp -v u-boot-sunxi-with-spl.bin /dev/mtd0 || {
    echo "Ошибка: Не удалось прошить U-Boot"
    umount "$MOUNT_POINT" 2>/dev/null
    exit 1
  }
else
  echo "Ошибка: Файл u-boot-sunxi-with-spl.bin не найден"
  umount "$MOUNT_POINT" 2>/dev/null
  exit 1
fi

# Размонтировать диск
umount "$MOUNT_POINT" 2>/dev/null

# 6. Завершение
echo "Скрипт успешно выполнен!"
echo "Теперь выключите устройство, извлеките SD карту и запустите устройство снова."

# Очистка временных файлов
rm -rf "$TMP_DIR"

exit 0
