import serial

PORT = 'COM16'
BAUD_RATE = 115200

ser = serial.Serial(PORT, BAUD_RATE)
print("Listening on", PORT)

while True:
    line = ser.readline().decode(errors='ignore').strip()

    if not line:
        continue

    parts = line.split(',')

    try:
        if parts[0] == "POS":
            lat = float(parts[1])
            lon = float(parts[2])
            alt = float(parts[3])
            print(f"Lat={lat:.7f}, Lon={lon:.7f}, Alt={alt:.1f}m", end="")

            if len(parts) >= 6 and parts[4] == "AS":
                airspeed = float(parts[5])
                print(f" | Airspeed={airspeed:.2f}", end="")

            print()

        elif parts[0] == "AS":
            airspeed = float(parts[1])
            print(f"Airspeed={airspeed:.2f}")

        else:
            print("RAW:", line)

    except (ValueError, IndexError) as e:
        print("Parse error:", e, "| RAW:", line)