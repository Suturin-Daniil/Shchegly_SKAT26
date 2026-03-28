import os
import cv2      # OpenCV

"""
Скрипт читает черно-белые изображения с типом input_type из папки input_dir
и сохраняет их с типом output_type в папку output_dir с ресайзом до output_size.
"""

input_size = 200
input_type = ".png"
output_size = 32
output_type = ".bmp"

# Папки
input_dir = f"{input_size}px"
output_dir = f"{output_size}px"

# Создаём выходную папку, если её нет
os.makedirs(output_dir, exist_ok=True)

# Проходим по всем файлам в папке input_dir
for filename in os.listdir(input_dir):
    # Проверяем, что файл имеет расширение input_type
    if filename.lower().endswith(input_type):
        # Формируем полные пути
        input_path = os.path.join(input_dir, filename)
        # Новое имя файла: меняем расширение на output_type
        name_without_ext = os.path.splitext(filename)[0]
        output_filename = name_without_ext + output_type
        output_path = os.path.join(output_dir, output_filename)

        # Читаем изображение
        img = cv2.imread(input_path, cv2.IMREAD_GRAYSCALE)
        if img is None:
            print(f"Не удалось прочитать {filename}, пропускаем.")
            continue

        # Изменяем размер до output_size
        resized = cv2.resize(img, (output_size, output_size), interpolation=cv2.INTER_AREA)

        # Сохраняем результат
        cv2.imwrite(output_path, resized)
        print(f"Обработано: {filename} -> {output_filename}")

print("Готово!")