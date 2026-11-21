# ZKTeco customer display implementation notes

## Hardware research

The Intel Celeron J1900 in the supplied Windows System Information screenshot is also listed for the ZKTeco ZK1515 and ZK15 POS families. This is a hardware-family match, not proof of the exact terminal model.

ZKTeco's published ZK1515 specifications describe:
- A standard 8-character high-definition LED digital-tube customer display.
- An optional attached VFD customer display and a second LCD display.
- A separate 20-column x 2-line customer display option.
- RS-232 serial connectivity on the terminal family.

ZKTeco's ZK-VFD accessory specifications describe a 2-line x 20-character display, USB/RS-232 interfaces, command modes ESC/POS, CD5220, DSP800 and UTC, and 2400/9600 baud rates.

The ZKPOS Restaurant manual's Pole Display section configures a COM port and selects LED or VFD. That describes the ZKPOS application's configuration; it does not publish the command protocol for the built-in 8-character LED module.

## What this branch implements

- Isolated serial customer-display service, separate from the receipt printer.
- COM-port discovery and a safe open/close port check that sends no bytes.
- Configurable baud rate and VFD command set (ESC/POS or CD5220).
- VFD test message.
- When an existing saved order is expanded in the desktop Orders page, send the last item and order total to an enabled 2x20 VFD.
- After payment is saved, send a payment/total message.
- Preferences are stored separately and display support is disabled by default.
- The root source mirror and active `clubdeal/` source tree are kept synchronized.

## Known limitations — intentionally not guessed

The built-in 8-character LED digital-tube controller protocol is not identified by the public ZK1515 product specification or the ZKPOS Pole Display setup instructions. This branch does not send VFD commands to that numeric LED module and does not claim that COM1 or COM2 is connected to it. The COM-port check only confirms Windows can open a port; it does not prove the display is wired to it.

The desktop app currently receives persisted orders from Firestore and has no local in-progress checkout cart. Therefore the current integration updates a VFD when a cashier expands/selects an order, and after payment; it cannot yet mirror each tap in a live cart that this app does not currently implement.

## References

- ZKTeco ZK1515 Series: https://zktecopos.com/zk1515_series
- ZKTeco ZK15 Series: https://zktecopos.com/zk15_series
- ZKTeco ZK-VFD accessory: https://zktecopos.com/vfd
- ZKPOS Restaurant manual, Pole Display section: https://forum.zktecopos.com/wp-content/uploads/2022/10/ZKPOS-Restaurant-User-Manual-5.0.0.pdf
- CD5220 Customer Display manual: https://cdn.barcodesinc.com/resources/CD5220_Manual.pdf
