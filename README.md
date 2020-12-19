# DMTV

![DMTV v2 PCB](/images/DMTVPCB.png)

DMTV or "Dot Matrix Television" is an embedded solution to pair with a an original GameBoy console to provide 800x600 60Hz VGA out graphics, NES controller input, custom color palettes, and toggleable scanlines.

Unlike the original DMTV, this version no longer requires an atmega32u4 for controller handling. This feature is now baked directly into the source code using a simple shift register! This allows for a simplified board and lower BOM cost than before. Also includes all new color palettes.

To access scanlines and alternate color palettes, simply press Start + Select + A/B. The toggle is executed on the falling edge of the button press.

## Getting Started

### Prerequisites

* Assembled DMTV v2 board (keep spi flash off board until after flashing)
* Windows/Linux computer (linux HIGHLY recommended)
* [APIO Icestorm](https://apiodoc.readthedocs.io/en/stable/) (iceCube2 will **NOT** synthesize source code correctly as it is not as optimized as APIO)
	* Either compile from source using APIO Icestorm or use provided precompiled binary
	* You can find install instructions on multiple platforms [here](https://apiodoc.readthedocs.io/en/stable/source/installation.html)
* Pomona SOIC-Clip Model 5252/buspirate v3.6 combo
	* This combo is for bypassing the expensive Lattice Diamond programmer cable
	* Pomona clip: https://www.digikey.com/product-detail/en/pomona-electronics/5252/501-2059-ND/745103
	* Buspirate v3.6: https://www.sparkfun.com/products/12942
* [flashrom](https://www.flashrom.org/Flashrom) 
* Not in the BOM, but a right angle NES port is required for controller support. You can find them [here](https://www.aliexpress.com/item/32827549549.html?spm=a2g0o.productlist.0.0.11e3692acsauoI&algo_pvid=a0c39696-6282-46c4-b619-8d788824134f&algo_expid=a0c39696-6282-46c4-b619-8d788824134f-5&btsid=0b0a555a16083483935633202e09b7&ws_ab_test=searchweb0_0,searchweb201602_,searchweb201603_)

### Flashing FPGA SPI Flash Memory

Once a binary is obtained either through synthesis of source or using the precompiled binary, connect the buspirate to the SOIC clip as shown below.

![Buspirate Connection](/images/Buspirate.png)

If using a binary output from APIO, you must resize the binary. Flashrom will not flash the spi memory until it is sized properly. Linux users, use the truncate command and windows users use your favorite hex editor to resize the binary.

For instructions on how to use buspirate with flashrom, use the official buspirate page on the flashrom website found here: https://flashrom.org/Bus_Pirate

After successful flash, solder to DMTV PCB.

### Notes on the HDL Code / Hardware

* Color palettes can be swapped for different color palettes if desired. The color code is RGB565 so any color space higher than that will need to be translated down. RGB888 can be added via hardware if desired as well, it will however reduce the amount of logic elements.
* If a different screen resolution is desired, swap out the current 40MHz oscillator for an oscialltor that matches timings consistant with that frequency. The code will need to be changed to reflect the profile as well. Use VGA profiles found here: http://tinyvga.com/vga-timing
* Resistor values go from greatest to smallest and are assigned such that the least significant assigned output pin for RGB goes to the highest ohm resistor downwards
	* i.e. R0 -> 8kohm, G -> 16kohm, B -> 8kohm, etc.


## Currently Known Issues

* Non currently found, please submit a pull request if you find one

## ToDo

* Add option to flash SPI flash via header instead
	* This was a challenge as there needs to be a way to sever the 3.3v power rail. If the SPI flash and the FPGA both have power then the SPI flash is not detected. The only work around known is to flash the SPI flash off the board and solder it on after flashing.
* SNES controller support

## Built With

* [APIO Icestorm](https://github.com/FPGAwars/apio)
* flashrom
* Eagle
* Sublime Text

## Versions

v1.0 - Initial release

## Contributing

Please feel free to issue a PR or edit code freely. Would love to have people contribute ideas!


## Authors

* **Postman** - *Head of engineering at Gamebox Systems*

## License

This project is licensed under the GPL-3.0 license, see attached license for info.

## Acknowledgments

* **ahhuhtal** - *DMTV v2 is based off of their gbvga project. Ahhuhtal, thank you for your wonderful description of how the first active pixel is after the falling edge of HSync. I was stuck on that for a long time.* - [ahhuhtal](https://github.com/ahhuhtal)