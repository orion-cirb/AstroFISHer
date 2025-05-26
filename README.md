# AstroFISHer

* **Developed by:** Héloïse
* **Developed for:** Philine
* **Team:** Cohen-Salmon
* **Date:** May 2025
* **Software:** Fiji


### Images description

2D images taken using a x40 oil immersion objective on a Zeiss videomicroscope.

3 channels:
  1. *DAPI:* Nuclei
  2. *EGFP:* Transfected astrocytes
  3. *Cy3:* RNAscope puncta (FISH)
     
### Macros description

#### AstroFISHer_automatic.ijm
Fully automated processing of images:
1. Segment cells using background subtraction + Gaussian blur + automatic thresholding + median filtering + size-selective hole filling + morphological opening + size filtering
2. Retain the cell closest to the image center
3. Segment nuclei using background subtraction + median filtering + automatic thresholding + median filtering + hole filling + watershed splitting + size filtering
4. Retain the nucleus closest to the centroid of the selected cell
5. Detect RNA puncta within the cell using Gaussian blur + maxima finding
6. Compute the distance from each RNA punctum to the centroid of the nucleus
   
#### AstroFISHer_manual.ijm
Semi-automated processing of images:

Use this macro when the cell automatic segmentation fails, particularly in images with weak cell signal. The macro prompts the user to manually draw the cell of interest before proceeding with nucleus segmentation, RNA puncta detection, and distance calculation.

### Dependencies

None

### Version history

Version 1 released on May 26, 2025.

