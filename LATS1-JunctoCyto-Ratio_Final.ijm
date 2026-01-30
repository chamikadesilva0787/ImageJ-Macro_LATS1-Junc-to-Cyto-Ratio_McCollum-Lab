// ======================================================================
// BATCH MACRO for MERGED TIFFS
// C1 (red)=LATS1, C2 (green)=TRIP6, C3 (blue)=DAPI
// Saves Nuclear/Junctional/Cytoplasmic masks and measures LATS1
// ======================================================================

requires("1.53");

// -------------------- Choose / set folders -----------------------------
inputDir    = getDirectory("Choose folder with original merged images");
nucDir      = getDirectory("Choose folder to SAVE Nuclear Masks");
juncDir     = getDirectory("Choose folder to SAVE Junctional Masks");
cytoDir     = getDirectory("Choose folder to SAVE Cytoplasmic Masks");
resultsDir  = getDirectory("Choose folder to SAVE Results");

// Timestamp for results file name (string concat so no NaN)
getDateAndTime(year, month, dayOfMonth, dayOfWeek, hour, minute, second, msec);
timeStamp = "" + year + "-" + month + "-" + dayOfMonth + "_" + hour + minute;
resultsPath = resultsDir + "LATS1_Junction_vs_Cytoplasm_" + timeStamp + ".csv";

// -------------------- Settings & helpers -------------------------------
setBatchMode(true);
run("Clear Results");
run("Set Measurements...", "area mean integrated limit redirect=None decimal=3");

// Pre-create column order so Region = 1st col, Image_Name = 2nd col
setResult("Region", 0, "");
setResult("Image_Name", 0, "");
updateResults();
run("Clear Results");

function safeClose(t) { if (isOpen(t)) { selectWindow(t); close(); } }

// -------------------- Main loop ----------------------------------------
list = getFileList(inputDir);

for (i = 0; i < list.length; i++) {

    name = list[i];

    // Only process names that contain "_Merged.tif" or "_Merged.tiff"
    if (indexOf(name, "_Merged.tif") < 0 && indexOf(name, "_Merged.tiff") < 0) continue;

    // ---- Open merged image
    open(inputDir + name);
    title = getTitle();
    baseName = replace(title, "_Merged.tif", "");
    baseName = replace(baseName, "_Merged.tiff", "");
    baseName = replace(baseName, ".tif", "");

    print("\\Clear");
    print("========================================================");
    print("Processing:", title);

    // ---- Split channels -> creates "C1-<title>", "C2-<title>", "C3-<title>"
    run("Split Channels");
    c1Title = "C1-" + title;
    c2Title = "C2-" + title;
    c3Title = "C3-" + title;

    // ===================== Nuclear mask from C3 =========================
    roiManager("Reset");
    selectWindow(c3Title);
    setOption("ScaleConversions", true);
    run("8-bit");
    run("Auto Threshold", "method=Yen white");
    run("Create Selection");
    roiManager("Add"); // ROI index 0 = Nuclear
    run("Create Mask");
    saveAs("Tiff", nucDir + "C3-" + baseName + "_Nuclear_Mask.tif");
    close();
    safeClose(c3Title);

    // ================== Junctional mask from C2 =========================
    selectWindow(c2Title);
    run("Subtract Background...", "rolling=50 light sliding");
    run("Bandpass Filter...", "filter_large=40 filter_small=3 suppress=None tolerance=5 autoscale saturate");
    setOption("ScaleConversions", true);
    run("8-bit");
    run("Auto Threshold", "method=Intermodes white");
    run("Create Selection");
    roiManager("Add"); // ROI index 1 = Junction
    run("Create Mask");
    saveAs("Tiff", juncDir + "C2-" + baseName + "_Junctional_Mask.tif");
    close();
    safeClose(c2Title);

    // ================== Cytoplasmic mask from C1 ========================
    selectWindow(c1Title);
    run("Duplicate...", "title=CytoWork");
    selectWindow("CytoWork");
    roiManager("Select", newArray(0,1));
    roiManager("Combine");
    setBackgroundColor(0,0,0);
    run("Clear", "slice");
    setOption("ScaleConversions", true);
    run("8-bit");
    run("Auto Local Threshold", "method=Phansalkar radius=20 parameter_1=0 parameter_2=0 white");
    run("Create Selection");
    roiManager("Add"); // ROI index 2 = Cytoplasm
    run("Create Mask");
    saveAs("Tiff", cytoDir + "C1-" + baseName + "_Cytoplasmic_Mask.tif");
    close();
    close("CytoWork");

    // ================== Measurements on LATS1 (C1) ======================
    selectWindow(c1Title);
    run("Duplicate...", "title=MeasureC1");
    selectWindow("MeasureC1");

    // 1) Junctional intensity (ROI 1)
    roiManager("Select", 1);
    run("Measure");
    setResult("Image_Name", nResults-1, baseName);
    setResult("Region", nResults-1, "Junction");

    // 2) Cytoplasmic intensity (ROI 2)
    roiManager("Select", 2);
    run("Measure");
    setResult("Image_Name", nResults-1, baseName);
    setResult("Region", nResults-1, "Cytoplasm");

    // ---- Calculate Junc/Cyto mean ratio; show only on Junction row -----
    rowJ = nResults - 2; // Junction row index
    rowC = nResults - 1; // Cytoplasm row index
    meanJ = getResult("Mean", rowJ);
    meanC = getResult("Mean", rowC);
    if (meanC == 0)
        ratio = 0;
    else
        ratio = meanJ / meanC;

    setResult("Junc_to_Cyto_Ratio", rowJ, ratio);  // visible on Junction row
    setResult("Junc_to_Cyto_Ratio", rowC, "");     // blank on Cytoplasm row
    // --------------------------------------------------------------------

    // Append results to CSV after each image
    saveAs("Results", resultsPath);

    // -------------- Cleanup before next iteration -----------------------
    close("MeasureC1");
    safeClose(c1Title);
    safeClose(title);

    print("Saved results to:", File.getName(resultsPath));
    print("Masks saved:",
        "\n   Nuclear:    C3-" + baseName + "_Nuclear_Mask.tif",
        "\n   Junctional: C2-" + baseName + "_Junctional_Mask.tif",
        "\n   Cytoplasmic:C1-" + baseName + "_Cytoplasmic_Mask.tif",
        "\n   Ratio (J/C):", ratio);
}

setBatchMode(false);
print("Done! Results at:\n" + resultsPath);
