# DMTV

DMTV or "Dot Matrix Television" is an embedded solution to pair with a an original GameBoy console to provide 800x600 60Hz VGA out graphics, NES controller input, custom color palettes, and toggleable scanlines.


## Getting Started


### Prerequisites

* Assembled DMTV board (keep spi flash off board until after flashing)
* Windows/Linux computer (linux HIGHLY recommended)
* APIO Icestorm (iceCube2 will **NOT** synthesize source code correctly as it is not as optimized as APIO)
	* Either compile from source using APIO Icestorm or use provided precompiled binary
* Arduino IDE
* Pomona SOIC-Clip Model 5252/buspirate v3.6 combo
	* This combo is for bypassing the expensive Lattice Diamond programmer cable
	* Pomona clip: https://www.digikey.com/product-detail/en/pomona-electronics/5252/501-2059-ND/745103
	* Buspirate v3.6: https://www.sparkfun.com/products/12942
* Arduino Uno for programming Atmega32u4
* flashrom 

### Flashing FPGA SPI Flash Memory

Once a binary is obtained either through synthesis of source or using the precompiled binary, connect the buspirate to the SOIC clip as shown below.

![Buspirate Connection](/images/Buspirate.png)

If using a binary output from APIO, you must resize the binary. Flashrom will not flash the spi memory until it is sized properly. Linux users, use the truncate command and windows users use your favorite hex editor to resize the binary.

For instructions on how to use buspirate with flashrom, use the official buspirate page on the flashrom website found here: https://flashrom.org/Bus_Pirate

After successful flash, solder to DMTV PCB.

### Flashing Atmega32u4 uC

Flash via Arduino IDE using Arduino ISP on the Arduino Uno. Use the ISP reference guide here: https://www.arduino.cc/en/tutorial/arduinoISP

Use Pins 10,11,12,13, 5v, and gnd instead of the ISP header.

### Notes on the HDL Code / Hardware

* Color palettes can be swapped for different color palettes if desired. The color code is RGB565 so any color space higher than that will need to be translated down. RGB888 can be added via hardware if desired as well, it will however reduce the amount of logic elements.
* If a different screen resolution is desired, swap out the current 40MHz oscillator for an oscialltor that matches timings consistant with that frequency. The code will need to be changed to reflect the profile as well. Use VGA profiles found here: http://tinyvga.com/vga-timing

## Currently Known Issues

* No button debounce implemented on FPGA side for toggling scanlines and palettes.

## Built With

* [APIO Icestorm](https://github.com/FPGAwars/apio)
* Arduino IDE
* flashrom

## Versions

v1.0 - Initial release

## Contributing

Please feel free to issue a PR or edit code freely. Would love to have people contribute ideas!


## Authors

* **Postman** - *Head of engineering at Gamebox Systems*

## License

This project is licensed under the GPL-3.0 license, see attached license for info.

## Acknowledgments

* **uXeBoy** - *Wrote base code DMTV is based off of* - [uXeBoy](https://github.com/uXeBoy)
	* Big thanks to uXeBoy for all the help with this project, you da bomb man!