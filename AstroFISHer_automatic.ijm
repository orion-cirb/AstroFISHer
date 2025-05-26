/*
 * Description: Segment the cell closest to the image center, identify its nucleus, detect RNA puncta within the cell, and compute the distance from each punctum to the nucleus centroid
 * Developed for: Philine, Cohen-Salmon's team
 * Author: Héloïse Monnet @ ORION-CIRB 
 * Date: May 2025
 * Repository: https://github.com/orion-cirb/AstroFISHer
 * Dependencies: None
*/


// PARAMETERS TO REVIEW BEFORE LAUNCHING MACRO //
cellsChannel = 2;
nucleiChannel = 1;
rnaPunctaChannel = 3;

cellsThresholdingMethod = "Huang";
minCellArea = 1500; // µm2
nucleiThesholdingMethod = "Otsu";
minNucleusArea = 150; // µm2
rnaPunctaProminence = 250;
////////////////////////////////////////////////


// Hide images during macro execution
setBatchMode(true);

// Ask for the images directory
inputDir = getDirectory("Please select a directory containing images to analyze");

// Create results directory
getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
resultDir = inputDir + "Results_" + year + "-" + (month+1) + "-" + dayOfMonth + "_" + hour + "-" + minute + "-" + second + File.separator();
if (!File.isDirectory(resultDir)) {
	File.makeDirectory(resultDir);
}

// Get all files in the input directory
inputFiles = getFileList(inputDir);

// Create results file and write headers in it
fileResults = File.open(resultDir + "results.csv");
print(fileResults, "Image name,Cell area (µm2),Nucleus area (µm2), RNA dot X position (µm), RNA dot Y position (µm), RNA dot is inside nucleus, RNA dot distance from nucleus centroid (µm)\n");
File.close(fileResults);

// Set foreground and background colors
Color.setForeground("white");
Color.setBackground("black");

// Loop through all files with .czi extension
for (i = 0; i < inputFiles.length; i++) {
    if (endsWith(inputFiles[i], ".czi")) {
    	print("Analyzing image " + inputFiles[i] + "...");
    	imgName = replace(inputFiles[i], ".czi", "");
		
		// SEGMENT CELL IN THE CENTER OF THE IMAGE
    	// Open cells channel
    	run("Bio-Formats Importer", "open=["+inputDir + inputFiles[i]+"] autoscale color_mode=Default specify_range split_channels view=Hyperstack stack_order=XYCZT c_begin="+cellsChannel+" c_end="+cellsChannel+" c_step=1");
		getPixelSize(unit, pixelWidth, pixelHeight);
		
		// Preprocessing
		run("Subtract Background...", "rolling=300 sliding");
		run("Gaussian Blur...", "sigma=4");
  		// Thresholding
		setAutoThreshold(cellsThresholdingMethod+" dark");
		setOption("BlackBackground", true);
		run("Convert to Mask");
		// Postprocessing
		run("Median...", "radius=10");
		fillHoles(0, 100);
		run("Options...", "iterations=10 count=1 black do=Open");
		// Filtering out cells with area < minCellArea
		run("Set Measurements...", "area centroid redirect=None decimal=2");
		run("Analyze Particles...", "size="+minCellArea+"-Infinity display clear add");
		rename("cellMask");
		
		// If multiple cells remain, keep only the one closest to the center of the image
		nbCells = nResults;
		if (nbCells == 0) {
			print("ERROR: No cells detected, image skipped.");
			closeAll();
			continue;
		} else if (nbCells > 1) {
			imgCenterX = getWidth()*pixelWidth*0.5; // µm
			imgCenterY = getHeight()*pixelHeight*0.5; // µm
			minDist = 1e6;
			cellId = 0;
			for (c=0; c < nbCells; c++) {
				tempDist = sqrt(pow(getResult("X", c)-imgCenterX,2) + pow(getResult("Y", c)-imgCenterY,2));
				if (tempDist < minDist)  {
					minDist = tempDist;
					cellId = c;
				}
			}
			selectWindow("cellMask");
			roiManager("select", cellId);
		} else {
			selectWindow("cellMask");
			roiManager("select", 0);
		}
		run("Clear Outside");
		roiManager("reset");
		run("Create Selection");
		roiManager("add");
		run("Clear Results");
		run("Measure");
		cellArea = getResult("Area", 0);
		cellCentroidX = getResult("X", 0);
		cellCentroidY = getResult("Y", 0);
		
		// SEGMENT NUCLEUS INSIDE CELL
		// Open nuclei channel
		run("Bio-Formats Importer", "open=["+inputDir + inputFiles[i]+"] autoscale color_mode=Default specify_range split_channels view=Hyperstack stack_order=XYCZT c_begin="+nucleiChannel+" c_end="+nucleiChannel+" c_step=1");
		
    	// Preprocessing
    	run("Subtract Background...", "rolling=300 sliding");
    	run("Median...", "radius=10");
		// Thresholding
		setAutoThreshold(nucleiThesholdingMethod+" dark");
		setOption("BlackBackground", true);
		run("Convert to Mask");
		// Postprocessing
		run("Median...", "radius=2");
		run("Fill Holes");
		run("Watershed", "");
		// Clear nuclei outside cell
		roiManager("select", 0);
		run("Clear Outside");
		// Filter out nuclei with area < minNucleusArea
		run("Analyze Particles...", "size="+minNucleusArea+"-Infinity display clear add");
		rename("nucleusMask");
		
		// If multiple nuclei remain, keep only the one closest to the centroid of the cell
		nbNuclei = nResults;
		if (nbNuclei == 0) {
			print("ERROR: No nucleus detected inside cell, image skipped.");
			closeAll();
			continue;
		} else if (nbNuclei > 1) {
			minDist = 1e6;
			nucleusId = 0;
			for (n=0; n < nbNuclei; n++) {
				tempDist = sqrt(pow(getResult("X", n)-cellCentroidX,2) + pow(getResult("Y", n)-cellCentroidY,2));
				if (tempDist < minDist)  {
					minDist = tempDist;
					nucleusId = n;
				}
			}
			selectWindow("nucleusMask");
			roiManager("select", nucleusId);
		} else {
			selectWindow("nucleusMask");
			roiManager("select", 0);
		}
		run("Clear Outside");
		roiManager("reset");
		roiManager("add");
		roiManager("select", 0);
		roiManager("rename", "nucleus");
		run("Clear Results");
		roiManager("measure");
		nucleusArea = getResult("Area", 0);
		nucleusCentroidX = getResult("X", 0);
		nucleusCentroidY = getResult("Y", 0);
		
		selectWindow("cellMask");
		run("Create Selection");
		roiManager("add");
		roiManager("select", 1);
		roiManager("rename", "cell");
		close("*");
		
		// DETECT RNA PUNCTA INSIDE CELL
		// Open RNA puncta channel
    	run("Bio-Formats Importer", "open=["+inputDir + inputFiles[i]+"] autoscale color_mode=Default specify_range split_channels view=Hyperstack stack_order=XYCZT c_begin="+rnaPunctaChannel+" c_end="+rnaPunctaChannel+" c_step=1");
    		
		// Clear RNA puncta outside cell
		roiManager("select", 1);
		run("Clear Outside");
		// Preprocessing
		run("Gaussian Blur...", "sigma=1");
		// Find maxima
		run("Find Maxima...", "prominence="+rnaPunctaProminence+" output=[Point Selection]");
		roiManager("add");
		roiManager("select", 2);
		roiManager("rename", "rna");
		run("Clear Results");
		roiManager("measure");
		
		// SAVE ROIS
		roiManager("deselect");
		roiManager("save", resultDir + imgName + ".zip");
			
		// SAVE PARAMETERS IN RESULTS FILE
		roiManager("select", 0);
		for(r=0; r < nResults; r++) {
			dotCentroidX = getResult("X", r);
			dotCentroidY = getResult("Y", r);
			insideNuc = Roi.contains(dotCentroidX/pixelWidth, dotCentroidY/pixelHeight);
			distNuc = sqrt(pow(dotCentroidX-nucleusCentroidX,2) + pow(dotCentroidY-nucleusCentroidY,2));
    		File.append(imgName+","+cellArea+","+nucleusArea+","+dotCentroidX+","+dotCentroidY+","+insideNuc+","+distNuc, resultDir+"results.csv");
		}
		
		closeAll();
    }
}

setBatchMode(false);

print("Analysis done!");


/******************** UTILS ********************/

// Close all open windows
function closeAll() {
	close("*");
	close("Results");
	roiManager("reset");
	close("ROI Manager");
}

// Fill holes whose area is between minHoleArea and maxHoleArea
function fillHoles(minHoleArea, maxHoleArea) {
	run("Invert");
	run("Analyze Particles...", "size=" + minHoleArea + "-" + maxHoleArea + " add");
	run("Invert");
	if (roiManager("count") > 0) {
		roiManager("deselect");
		roiManager("combine");
		run("Fill", "slice");
		roiManager("reset");
		run("Select None");
	}
}

/***********************************************/
