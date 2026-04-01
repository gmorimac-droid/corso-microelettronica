#!/usr/bin/env wish

package require Tk 8.6

namespace eval rb {
    variable currentRoot ""
    variable selectedPath ""
    variable filterText ""
    variable ui
    variable previewImage ""
}

# --------------------------------------------------
# Utility
# --------------------------------------------------
proc rb::logStatus {msg} {
    .status configure -text "Stato: $msg"
}

proc rb::openPath {path} {
    if {$path eq ""} { return }
    if {![file exists $path]} {
        tk_messageBox -icon warning -title "Percorso non trovato" \
            -message "Il percorso non esiste:\n$path"
        return
    }

    if {$::tcl_platform(platform) eq "windows"} {
        catch {exec {*}[auto_execok start] "" $path &}
    } elseif {$::tcl_platform(os) eq "Darwin"} {
        catch {exec open $path &}
    } else {
        catch {exec xdg-open $path &}
    }
}

proc rb::isTextFile {path} {
    set ext [string tolower [file extension $path]]
    expr {$ext in {.log .txt .json .csv .tcl .md .yaml .yml .ini .cfg .conf .xml}}
}

proc rb::isImageFile {path} {
    set ext [string tolower [file extension $path]]
    expr {$ext in {.png .jpg .jpeg .gif}}
}

proc rb::humanSize {bytes} {
    if {$bytes < 1024} {
        return "${bytes} B"
    } elseif {$bytes < 1024*1024} {
        return [format "%.1f KB" [expr {$bytes / 1024.0}]]
    } elseif {$bytes < 1024*1024*1024} {
        return [format "%.1f MB" [expr {$bytes / (1024.0*1024.0)}]]
    } else {
        return [format "%.1f GB" [expr {$bytes / (1024.0*1024.0*1024.0)}]]
    }
}

proc rb::matchFilter {path} {
    variable filterText
    set filter [string trim [string tolower $filterText]]
    if {$filter eq ""} {
        return 1
    }

    set name [string tolower [file tail $path]]
    set ext [string tolower [file extension $path]]

    foreach token [split $filter ", "] {
        set token [string trim $token]
        if {$token eq ""} { continue }

        if {[string match ".*" $token]} {
            if {$ext eq $token} { return 1 }
        } else {
            if {[string first $token $name] >= 0} { return 1 }
        }
    }
    return 0
}

# --------------------------------------------------
# Tree building
# --------------------------------------------------
proc rb::clearTree {} {
    variable ui
    set tree $ui(tree)
    foreach item [$tree children {}] {
        $tree delete $item
    }
}

proc rb::insertPathRecursive {parent path} {
    variable ui
    set tree $ui(tree)

    if {[file isdirectory $path]} {
        set id [$tree insert $parent end -text [file tail $path] -values [list $path dir]]
        foreach child [lsort -dictionary [glob -nocomplain -directory $path *]] {
            if {[file isdirectory $child]} {
                rb::insertPathRecursive $id $child
            } else {
                if {[rb::matchFilter $child]} {
                    $tree insert $id end -text [file tail $child] -values [list $child file]
                }
            }
        }
        # se cartella vuota e non ha figli file matching, resta visibile
        return $id
    } else {
        if {[rb::matchFilter $path]} {
            return [$tree insert $parent end -text [file tail $path] -values [list $path file]]
        }
    }
    return ""
}

proc rb::populateTree {} {
    variable currentRoot
    variable ui

    rb::clearTree

    if {$currentRoot eq "" || ![file exists $currentRoot]} {
        rb::logStatus "nessuna root selezionata"
        return
    }

    set tree $ui(tree)
    set rootId [$tree insert {} end -text [file tail $currentRoot] -open 1 -values [list $currentRoot dir]]

    foreach child [lsort -dictionary [glob -nocomplain -directory $currentRoot *]] {
        if {[file isdirectory $child]} {
            rb::insertPathRecursive $rootId $child
        } else {
            if {[rb::matchFilter $child]} {
                $tree insert $rootId end -text [file tail $child] -values [list $child file]
            }
        }
    }

    rb::logStatus "browser aggiornato"
}

# --------------------------------------------------
# Preview
# --------------------------------------------------
proc rb::clearPreview {} {
    variable ui
    variable previewImage

    $ui(infoPath) configure -text ""
    $ui(infoType) configure -text ""
    $ui(infoSize) configure -text ""
    $ui(infoMtime) configure -text ""

    $ui(textPreview) configure -state normal
    $ui(textPreview) delete 1.0 end
    $ui(textPreview) configure -state disabled

    catch {$ui(imageLabel) configure -image ""}
    catch {image delete $previewImage}
    set previewImage ""
}

proc rb::showTextPreview {path} {
    variable ui

    if {[catch {
        set ch [open $path r]
        set content [read $ch 65536]
        close $ch
    } err]} {
        set content "Errore lettura file:\n$err"
    }

    $ui(textPreview) configure -state normal
    $ui(textPreview) delete 1.0 end
    $ui(textPreview) insert end $content
    $ui(textPreview) configure -state disabled
}

proc rb::showImagePreview {path} {
    variable ui
    variable previewImage

    catch {image delete $previewImage}
    set previewImage ""

    if {[catch {
        set img [image create photo -file $path]
        set previewImage $img
        $ui(imageLabel) configure -image $img
    } err]} {
        $ui(textPreview) configure -state normal
        $ui(textPreview) delete 1.0 end
        $ui(textPreview) insert end "Errore caricamento immagine:\n$err"
        $ui(textPreview) configure -state disabled
    }
}

proc rb::showBinarySummary {path} {
    variable ui
    set ext [string tolower [file extension $path]]

    set msg "Anteprima non disponibile per questo tipo di file.\n\n"
    append msg "Estensione: $ext\n"
    append msg "Aprilo esternamente per ispezione dettagliata."

    $ui(textPreview) configure -state normal
    $ui(textPreview) delete 1.0 end
    $ui(textPreview) insert end $msg
    $ui(textPreview) configure -state disabled
}

proc rb::updateSelectionInfo {path} {
    variable ui
    variable selectedPath

    set selectedPath $path
    rb::clearPreview

    if {$path eq "" || ![file exists $path]} {
        return
    }

    set kind [expr {[file isdirectory $path] ? "Directory" : "File"}]
    set size "-"
    if {![file isdirectory $path]} {
        set size [rb::humanSize [file size $path]]
    }
    set mtime [clock format [file mtime $path] -format "%Y-%m-%d %H:%M:%S"]

    $ui(infoPath) configure -text $path
    $ui(infoType) configure -text $kind
    $ui(infoSize) configure -text $size
    $ui(infoMtime) configure -text $mtime

    if {[file isdirectory $path]} {
        $ui(textPreview) configure -state normal
        $ui(textPreview) delete 1.0 end
        $ui(textPreview) insert end "Directory selezionata.\n\nUsa 'Apri esternamente' o naviga nei file."
        $ui(textPreview) configure -state disabled
        return
    }

    if {[rb::isImageFile $path]} {
        rb::showImagePreview $path
    } elseif {[rb::isTextFile $path]} {
        rb::showTextPreview $path
    } else {
        rb::showBinarySummary $path
    }
}

# --------------------------------------------------
# Actions
# --------------------------------------------------
proc rb::chooseRoot {} {
    variable currentRoot
    set d [tk_chooseDirectory -title "Seleziona cartella risultati"]
    if {$d eq ""} { return }

    set currentRoot $d
    .top.rootEntry delete 0 end
    .top.rootEntry insert 0 $d
    rb::populateTree
}

proc rb::refresh {} {
    variable currentRoot
    set currentRoot [.top.rootEntry get]
    rb::populateTree
}

proc rb::openExternalSelected {} {
    variable selectedPath
    if {$selectedPath eq ""} {
        return
    }
    rb::openPath $selectedPath
}

proc rb::openParentDir {} {
    variable selectedPath
    if {$selectedPath eq ""} { return }

    if {[file isdirectory $selectedPath]} {
        rb::openPath $selectedPath
    } else {
        rb::openPath [file dirname $selectedPath]
    }
}

proc rb::applyFilter {} {
    rb::populateTree
}

proc rb::onTreeSelect {} {
    variable ui
    set tree $ui(tree)
    set sel [$tree selection]
    if {$sel eq ""} { return }

    set item [lindex $sel 0]
    set path [$tree set $item path]
    rb::updateSelectionInfo $path
}

proc rb::loadSampleResults {} {
    variable currentRoot

    set base [file normalize "./sample_results"]
    file mkdir $base
    file mkdir [file join $base logs]
    file mkdir [file join $base reports]
    file mkdir [file join $base images]

    set f [open [file join $base logs run.log] w]
    puts $f "[12:00:01] INFO start run"
    puts $f "[12:00:02] WARN fallback calibration"
    puts $f "[12:00:03] ERROR target mismatch"
    close $f

    set f [open [file join $base reports metrics.csv] w]
    puts $f "metric,value"
    puts $f "rmse,1.24"
    puts $f "pd,0.91"
    puts $f "pfa,0.03"
    close $f

    set f [open [file join $base config.json] w]
    puts $f "{"
    puts $f "  \"domain\": \"radar\","
    puts $f "  \"case_name\": \"sample_case\""
    puts $f "}"
    close $f

    set currentRoot $base
    .top.rootEntry delete 0 end
    .top.rootEntry insert 0 $base
    rb::populateTree
    rb::logStatus "sample results caricati"
}

# --------------------------------------------------
# UI
# --------------------------------------------------
proc rb::buildUI {} {
    variable ui

    wm title . "Result Browser"
    wm geometry . 1350x860
    wm minsize . 1080 720
    ttk::style theme use clam

    ttk::frame .top -padding 6
    pack .top -fill x

    ttk::button .top.chooseBtn -text "Apri cartella" -command rb::chooseRoot
    ttk::button .top.refreshBtn -text "Refresh" -command rb::refresh
    ttk::button .top.sampleBtn -text "Sample" -command rb::loadSampleResults
    ttk::button .top.openBtn -text "Apri esternamente" -command rb::openExternalSelected
    ttk::button .top.parentBtn -text "Apri cartella padre" -command rb::openParentDir

    ttk::label .top.rootLabel -text "Root:"
    entry .top.rootEntry

    ttk::label .top.filterLabel -text "Filtro:"
    ttk::entry .top.filterEntry -textvariable rb::filterText
    ttk::button .top.filterBtn -text "Applica filtro" -command rb::applyFilter

    pack .top.chooseBtn .top.refreshBtn .top.sampleBtn .top.openBtn .top.parentBtn -side left -padx 3
    pack .top.filterBtn -side right -padx 3
    pack .top.filterEntry -side right -padx 3
    pack .top.filterLabel -side right -padx 3
    pack .top.rootEntry -side right -fill x -expand 1 -padx 3
    pack .top.rootLabel -side right -padx 3

    ttk::panedwindow .pw -orient horizontal
    pack .pw -fill both -expand 1

    ttk::frame .left -padding 6
    ttk::frame .right -padding 6
    .pw add .left -weight 2
    .pw add .right -weight 3

    # Left: tree
    ttk::labelframe .left.box -text "Output tree" -padding 6
    pack .left.box -fill both -expand 1

    set ui(tree) [ttk::treeview .left.box.tree \
        -columns {path kind} -show tree -selectmode browse]
    ttk::scrollbar .left.box.vsb -orient vertical -command "$ui(tree) yview"
    ttk::scrollbar .left.box.hsb -orient horizontal -command "$ui(tree) xview"
    $ui(tree) configure -yscrollcommand ".left.box.vsb set" -xscrollcommand ".left.box.hsb set"

    grid $ui(tree) -row 0 -column 0 -sticky nsew
    grid .left.box.vsb -row 0 -column 1 -sticky ns
    grid .left.box.hsb -row 1 -column 0 -sticky ew
    grid rowconfigure .left.box 0 -weight 1
    grid columnconfigure .left.box 0 -weight 1

    bind $ui(tree) <<TreeviewSelect>> rb::onTreeSelect
    bind .top.filterEntry <Return> {rb::applyFilter}

    # Right: info + preview
    ttk::labelframe .right.info -text "Info file" -padding 10
    pack .right.info -fill x

    grid columnconfigure .right.info 1 -weight 1

    ttk::label .right.info.l1 -text "Path:"
    ttk::label .right.info.v1 -text "" -wraplength 700 -justify left
    ttk::label .right.info.l2 -text "Tipo:"
    ttk::label .right.info.v2 -text ""
    ttk::label .right.info.l3 -text "Dimensione:"
    ttk::label .right.info.v3 -text ""
    ttk::label .right.info.l4 -text "Modifica:"
    ttk::label .right.info.v4 -text ""

    grid .right.info.l1 -row 0 -column 0 -sticky nw -pady 3
    grid .right.info.v1 -row 0 -column 1 -sticky w -pady 3
    grid .right.info.l2 -row 1 -column 0 -sticky w -pady 3
    grid .right.info.v2 -row 1 -column 1 -sticky w -pady 3
    grid .right.info.l3 -row 2 -column 0 -sticky w -pady 3
    grid .right.info.v3 -row 2 -column 1 -sticky w -pady 3
    grid .right.info.l4 -row 3 -column 0 -sticky w -pady 3
    grid .right.info.v4 -row 3 -column 1 -sticky w -pady 3

    set ui(infoPath)  .right.info.v1
    set ui(infoType)  .right.info.v2
    set ui(infoSize)  .right.info.v3
    set ui(infoMtime) .right.info.v4

    ttk::labelframe .right.preview -text "Preview" -padding 8
    pack .right.preview -fill both -expand 1 -pady 8

    ttk::notebook .right.preview.nb
    pack .right.preview.nb -fill both -expand 1

    ttk::frame .right.preview.textTab
    ttk::frame .right.preview.imageTab

    .right.preview.nb add .right.preview.textTab -text "Text"
    .right.preview.nb add .right.preview.imageTab -text "Image"

    set ui(textPreview) [text .right.preview.textTab.txt -wrap none -state disabled]
    ttk::scrollbar .right.preview.textTab.vsb -orient vertical -command "$ui(textPreview) yview"
    ttk::scrollbar .right.preview.textTab.hsb -orient horizontal -command "$ui(textPreview) xview"
    $ui(textPreview) configure -yscrollcommand ".right.preview.textTab.vsb set" \
        -xscrollcommand ".right.preview.textTab.hsb set"

    grid $ui(textPreview) -row 0 -column 0 -sticky nsew
    grid .right.preview.textTab.vsb -row 0 -column 1 -sticky ns
    grid .right.preview.textTab.hsb -row 1 -column 0 -sticky ew
    grid rowconfigure .right.preview.textTab 0 -weight 1
    grid columnconfigure .right.preview.textTab 0 -weight 1

    set ui(imageLabel) [label .right.preview.imageTab.img -anchor center]
    pack $ui(imageLabel) -fill both -expand 1

    ttk::separator .sep -orient horizontal
    pack .sep -fill x

    ttk::label .status -text "Stato: pronto" -padding 6
    pack .status -fill x
}

rb::buildUI
rb::logStatus "pronto"