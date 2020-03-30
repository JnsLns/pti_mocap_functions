
# Functions for motion capturing experiments using Phoenix Technologies Visualeyez VZ4000 trackers.

This set of MATLAB functions allows dealing with data streamed into MATLAB from motion trackers via the VzGetDat function (available from Phoenix Technologies), including checks of data quality and computing pointer positions based on multiple markers mounted on a pointer device. In addition, a visualizing tool allows plotting data live or from existing files.

There is extensive documentation within each function file. Here's a quick overview:

### Visualization

* `vzpVisualizer` is a GUI-based tool that allows visualizing both pre-recorded tracking data (\*.vzp or \*.mat files) and data streamed live from the motion tracker system.

![vzp Visualizer window](doc_images/vzp_visualizer.jpg "Vzp Visualizer Window")

### Data quality

* `batteryCheck` checks whether the batteries of wireless SIM markers might be exhausted.

* `zeroDataCheck` checks whether marker coordinate data obtained from VzGetDat is free of zero rows. This may be caused by marker occlusion, empty batteries on wireless markers, and similar things. (Use `batteryCheck.m` to
more explicitly check for depleted batteries.)

* `bufferUpdateCheck` checks whether positional data obtained from VzGetDat is different to that obtained in the last function call for all markers. Helps dealing with the issue that MATLAB loops usually run at a higher frequency than the frequency at which VzGetDat can return new data.

* `goodDataCheck` wraps `zeroDataCheck` and `bufferUpdateCheck`.

* `markerJumpCheck` checks whether tracker markers moved a larger distance than expected since this function was called last. Such overly fast movement usually indicates erroneous measurements, for instance due to reflections.

* `markerDistanceCheck` computes distances between tracker markers for a set of marker pairings, compares them to a set of expected distances, and checks whether any of the differences exceeds a threshold value. Can be used to detect erroneous marker localizations (e.g., due to reflections) in setups where multiple markers are mounted at fixed positions on a rigid body so that their distances should usually remain constant. Obtain initial marker distances using `getMarkerDistances`.

* `getMarkerDistances` calls VzGetDat to obtain marker position data and computes distances between markers for all possible marker pairings, or for a defined subset of pairings. Use this function's output as input to `markerDistanceCheck`.

### Calibrating and using a pointer device

* `calibratePointer` Given a pointer device, that is, a rigid body on which three tracker markers are mounted, compute a set of coefficients that will allow mapping from these markers' positions to the position of the pointer's tip (use `tipPosition` for that).

* `doCalibrationProcedure` leads the user through the pointer calibration procedure (that usually has to be performed at the outset of an experimental session) using message boxes. Wraps `calibratePointer`.

* `tipPosition` Computes tip location of a pointer device equipped with three tracker markers based on data obtained via VzGetDat. The computation relies on coefficients obtained during pointer calibration using the function `calibratePointer`.

* `transformedTipPosition`, like `tipPosition` computes tip location of a pointer equipped with three tracker markers, based on data obtained via VzGetDat. In addition, this function transforms the computed position into a coordinate frame that is itself defined by three markers, one located at the frame's origin, one on the x-axis, and one in the positive x-y-plane. The coordinate frame is updated when the defining markers move, so equipping for instance a screen with markers allows to consistently map pointer position to a screen even when both the screen and the pointer move.

### Helper functions

* `filterTrackerData`. Pass in data matrix obtained directly from VzGetDat and list of TCM/LED IDs, get back only data rows corresponding to matching markers. 

* `markerIdsToRows`. Pss in data matrix obtained directly from VzGetDat and list of TCM/LED IDs, get back row indices that correspond to matching markers. 

* `changeOfBasis` transforms a coordinate vector to a new basis that is defined by means of three points: one at the new origin, one on the positive x-axis, and one in the positive x-y-plane. 

* `dist3d` computes Euclidean distance between one an multiple other points in 3d space.

* `posFrom3Points` computes a point in 3D space as the linear combination of three known points and a set of coefficients that specify the relative position to the sought point.





