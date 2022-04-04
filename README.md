---
typora-root-url: screenshots
---

# **Technical Selection - Task A - Richard Thomson**

## Description

I have written some Matlab code that accesses data from the GBR4 model. It performs the following tasks:

1. The GUI visualises the temperature field as a 2D map at a selectable depth and selectable time over the range of latitude & longitude coordinates available. The source URL is also modifiable to access data from a different day.

2. Also included is the **stretch objective**: the current data can be overlaid on the temperature plot

3. In addition, I have also added a coordinate selector button that will produce a temperature map over all Depths and DateTimes for a user-selected latitude & longitude (I was enjoying the project!)

   

## Installation

Please clone or download the repository: https://github.com/RThomson-Tech-Application/eReef

The code is supplied as a Matlab App. 

##### If a Matlab R2021b or greater installation is available:

Matlab toolboxes required: Mapping, Image Processing.

The two `reefmap` files in the repo are also required to display the map as a background

The program can be run as a script within a Matlab installation (limited capability if not R2021b or above) using either `ereef.mlapp` or `ereef.m`

##### If a Matlab installation is not available:

The program may be installed using `ereef_setup.exe`

https://github.com/RThomson-Tech-Application/eReef/blob/main/eReef_setup.exe

This will also download the *Matlab Runtime Environment* (~700M)



## Features

The GUI visualises the temperature field as a 2D map at a **selectable depth** (Elevation / zc) and **selectable time** over the range of latitude & longitude coordinates available. The background map was borrowed from your website!

![](/mainGui.PNG)



### Control Panel

#### ![](/controlPanel_URL.png)

1. The *Data Source URL* can be modified to access data from a **different day**. The URL is checked for validity and the presence of expected data

2. *Scale Temperature Colour Bar*: When checked (off by default), this adjusts the ColourBar to the right of the map to maximise the colour contrast of the range of **temperatures** present at a particular depth & time. If unchecked (default), the temperature colour scale remains constant

3. *Show Currents:* When checked (default) , **current directions and amplitudes** are displayed on top of the temperature map

   *Autoscale Currents:* When unchecked (off by default), current amplitudes are relative to the size of the arrow in the bottom left of the map (see pic below, 1 m/s). If checked, currents are autoscaled to maximise contrast of the sizes. If auto scaling is on, note that the amplitude scale is **not** displayed.

     ![](/currentsScale.PNG)



### Temperature with respect to Time & Elevation (Depth/zc) 

By clicking the following button:

![](/button.PNG)

a crosshairs will appear (this feature in Matlab is slow unfortunately) allowing the user to select a **specific longitude and latitude**.

This will spawn a new figure showing the **temperature** **map** with respect to the **depth** and the **time**:

![](/tempDepthTimeMap.PNG)



The user can click on the map to display the **Temperature** at a specific **Time** and **Elevation**. This also shows the **lowest depth** (white = no data), in this case 315m