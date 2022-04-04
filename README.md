

# **Technical Selection - Task A - Richard Thomson**

GPL-3.0 license

## Description

I have written some **Matlab** code that accesses data via **OPeNDAP** from the GBR4 model. It performs the following tasks:

1. The GUI visualises the temperature field as a 2D map at a **selectable depth** and **selectable time** over the range of latitude & longitude coordinates available. The source URL is also modifiable to access data from a **different day**.

2. Also included is the **stretch objective**: the **currents (u,v) data can be overlaid** on the temperature plot

3. In addition, I have also added a coordinate selector button that will produce a **temperature map over all Depths and DateTimes** for a user-selected latitude & longitude (I was enjoying the project!)

   

## Installation

Please clone or download the repository: https://github.com/RThomson-Tech-Application/eReef

The code is supplied as a Matlab App. 

##### <u>If a Matlab R2021b or greater installation is available:</u>

Matlab toolboxes required: *Mapping*, *Image Processing*.

The two `reefmap` files in the repo are also required to display the map as a background

The program can be run as a script within a Matlab installation (limited capability if not R2021b or above) using either `ereef.mlapp` or `ereef.m`

##### <u>If a Matlab installation is not available:</u>

The program may be installed using `eReef_setup.exe`

https://github.com/RThomson-Tech-Application/eReef/blob/main/eReef_setup.exe

This will also **automatically** download the *[Matlab Runtime Environment](https://au.mathworks.com/products/compiler/matlab-runtime.html)* (~700MB)



## Features

The GUI visualises the temperature field as a 2D map at a **selectable depth** (Elevation / zc) and **selectable time** over the range of latitude & longitude coordinates available. The background map was borrowed from your website! It was converted to a geotiff manually and is *approximately* aligned to the latitudes/longitudes.

![](/screenshots/mainGui.PNG)



The map can be **zoomed in, out, and panned**:

![](/screenshots/mapZoom.png)



### Control Panel

#### ![](/screenshots/controlPanel2.png)

1. The *Data Source URL* can be modified to access data from a **different day**. The URL is checked for validity and the presence of expected data

2. *Scale Temperature Colour Bar*: When checked (off by default), this adjusts the ColourBar to the right of the map to maximise the colour contrast of the range of **temperatures** present at a particular depth & time. If unchecked (default), the temperature colour scale remains constant

3. *Show Currents:* When checked (default) , **current directions and amplitudes** are displayed on top of the temperature map

   *Autoscale Currents:* When unchecked (off by default), current amplitudes are relative to the size of the arrow in the bottom left of the map (see pic below, 1 m/s). If checked, currents are autoscaled to maximise contrast of the sizes. If auto scaling is on, note that the amplitude scale is **not** displayed.

     ![](/screenshots/currentsScale.PNG)



### Temperature with respect to Time & Elevation (Depth/zc) 

By clicking the following button:

![](/screenshots/button.PNG)

a crosshairs will appear (this feature in Matlab is slow unfortunately) allowing the user to select a **specific longitude and latitude**. A red asterisk will appear on the map.

This will then spawn a new figure showing the **temperature** **map** with respect to the **depth** (elevation) and the **time**:

![](/screenshots/tempDepthTimeMap.PNG)

The user can click on the map to display the **Temperature** at a specific **Time** and **Elevation**. This also shows the **lowest depth** (white = no data), in this case 315m

### Additional options

![](/screenshots/scaleFactors.png)

*Scale Factor Temp* and *Scale Factor Currents* designate what quantity of points to plot i.e. if the scale factor for currents = 1000, it will only plot every 1000th current vector. If currents is set to 1, it is difficult to see what is going on unless zoomed in!



## Error checking

* If no internet connection is available or the server is down, the user is informed
* If a new datasource URL is entered, it is checked for accessibility and its contents are validated (presence of i,j,k,time)
* The dimensions of i,j,k, and time are not hard-coded
* The maximum allowable temperature is 60C
* The code has limited functionality for R2019 and attempts to continue are made, however it should be run on R2021b or greater (or installed with the *Matlab Runtime Environment* via `ereef_setup.exe`)
* If the map files `reefmap.tif` and `reefmap.tfw` are missing, it will attempt to display the temperature map regardless
* The user is warned if a coordinate is selected that is greater than 0.2 degrees away from a known longitude/latitude



## Validation

Temperature displayed at a specific location, specific time, specific depth matches server data:



![](/screenshots/validation.PNG)





