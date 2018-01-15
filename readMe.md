## BJUtils

**This should not be used on any device other than my personal main phone**

I thought a lot of things about this project were pretty cool, so I wanted to share. Using this on your device will be totally useless. All posts to my server are locked down to my VPN. 

Functionality:

-  A TCP server running in SpringBoard (allows requests that come in to interact with SpringBoard)

- Changing wallpaper (triggered by Activator or aforementioned server)

- Push wallpaper changes to my server for [public viewing](https://ipadkid.cf/status/wallpaper.jpg)

- Serves the music information used to power [Current Music](https://ipadkid.cf/status/music)

- Notify, and provide options for when there is a problem with a connection to my VPN

- Battery information available via Activator gesture (I guess anyone can use this)

- A fun [Find My iPhone](https://www.apple.com/icloud/find-my-iphone/) replacement, including sounds and location

- Activator listener to display prayer time information

- Show current weather information via Activator gesture

- Light weight Activator gesture to connect to Bluetooth headphones

### Notes

All additional headers not part of the public SDK or theos-vendor-include have links to where I got them from

A lot of things in BJSupport are different from my normal style, because this is SpringBoard, and I wanted to use the least amount of memory possible. Usually I want to do the least amount of executions possible, but here I decided against that, and repeat a few things to limit memory usage over long periods of time. Another thing is very few things happen on the main thread. Unless absolutely necessary, again because this is SpringBoard, everything is executed on a background thread

Weather icons are provided by [AccuWeather](https://developer.accuweather.com/weather-icons)
All other icons are property of veerklempt, Veexillum author
