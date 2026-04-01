#!/usr/bin/env wish

package require Tk 8.6

namespace eval cfged {
    variable currentFile ""
    variable currentDomain "radar"

    variable ui
    variable fieldVars
    array set fieldVars {}

    variable widgetsByField
    array set widgetsByField {}

    variable comboValues
    array set comboValues {}

    variable commonSections {general io notes}
    variable domainSections {scenario sensor processing}
}

# --------------------------------------------------
# Schema domain-aware
# --------------------------------------------------
proc cfged::domainFieldSpecs {} {
    return {
        common {
            {general case_name     "Case name"     entry}
            {general description   "Description"   entry}
            {io      input_data    "Input data"    entry}
            {io      output_dir    "Output dir"    entry}
            {notes   author        "Author"        entry}
            {notes   tags          "Tags"          entry}
        }

        radar {
            {scenario duration_s          "Duration [s]"           entry}
            {scenario fs_hz               "Sampling freq [Hz]"     entry}
            {scenario target_count        "Target count"           entry}
            {scenario environment         "Environment"            combo {nominal clutter jamming}}
            {sensor   fc_hz               "Carrier freq [Hz]"      entry}
            {sensor   bandwidth_hz        "Bandwidth [Hz]"         entry}
            {sensor   tx_power_w          "TX power [W]"           entry}
            {sensor   gain_db             "Gain [dB]"              entry}
            {processing threshold_mode    "Threshold mode"         combo {cfar fixed adaptive}}
            {processing integration_pulses "Integration pulses"    entry}
            {processing tracker           "Tracker"                combo {kalman particle none}}
        }

        satellite {
            {scenario duration_s          "Duration [s]"           entry}
            {scenario step_s              "Step [s]"               entry}
            {scenario orbit_type          "Orbit type"             combo {LEO MEO GEO HEO}}
            {scenario environment         "Environment"            combo {nominal eclipse perturbed}}
            {sensor   fov_deg             "FoV [deg]"              entry}
            {sensor   altitude_m          "Altitude [m]"           entry}
            {sensor   gain_db             "Gain [dB]"              entry}
            {sensor   pointing_mode       "Pointing mode"          combo {nadir target inertial}}
            {processing coverage_mode     "Coverage mode"          combo {footprint access revisit}}
            {processing export_access_windows "Export access windows" combo {0 1}}
            {processing estimator         "Estimator"              combo {deterministic montecarlo}}
        }

        underwater {
            {scenario duration_s          "Duration [s]"           entry}
            {scenario fs_hz               "Sampling freq [Hz]"     entry}
            {scenario target_count        "Target count"           entry}
            {scenario environment         "Environment"            combo {sea_state_1 sea_state_2 sea_state_3 harbor}}
            {sensor   center_freq_hz      "Center freq [Hz]"       entry}
            {sensor   array_elements      "Array elements"         entry}
            {sensor   gain_db             "Gain [dB]"              entry}
            {sensor   platform_speed_ms   "Platform speed [m/s]"   entry}
            {processing beamforming       "Beamforming"            combo {delay_sum mvdr music}}
            {processing detector          "Detector"               combo {energy matched_filter adaptive}}
            {processing threshold_mode    "Threshold mode"         combo {adaptive fixed}}
        }

        hdl {
            {scenario timescale           "Timescale"              combo {1ns/1ps 1ps/1ps 10ns/1ns}}
            {scenario seed                "Seed"                   entry}
            {scenario environment         "Environment"            combo {sim regress debug}}
            {sensor   dut_name            "DUT name"               entry}
            {sensor   clock_mhz           "Clock [MHz]"            entry}
            {sensor   reset_cycles        "Reset cycles"           entry}
            {sensor   interface_mode      "Interface mode"         combo {axi_stream axi_lite custom}}
            {processing suite             "Suite"                  combo {smoke nightly regression full}}
            {processing waves             "Waves"                  combo {0 1}}
            {processing coverage          "Coverage"               combo {0 1}}
            {processing checker_mode      "Checker mode"           combo {basic full debug}}
        }
    }
}

proc cfged::fieldSpecsForDomain {domain} {
    set specs [cfged::domainFieldSpecs]
    set result [dict get $specs common]
    foreach row [dict get $specs $domain] {
        lappend result $row
    }
    return $result
}

# --------------------------------------------------
# Preset
# --------------------------------------------------
proc cfged::presetRadar {} {
    return [dict create \
        domain radar \
        general [dict create case_name "radar_case_01" description "Scenario radar batch base"] \
        scenario [dict create duration_s 120 fs_hz 1000000 target_count 3 environment "nominal"] \
        sensor [dict create fc_hz 9400000000 bandwidth_hz 20000000 tx_power_w 1000 gain_db 32] \
        processing [dict create threshold_mode "cfar" integration_pulses 16 tracker "kalman"] \
        io [dict create input_data "data/iq_capture.bin" output_dir "./runs/radar"] \
        notes [dict create author "" tags "batch,test"]]
}

proc cfged::presetSatellite {} {
    return [dict create \
        domain satellite \
        general [dict create case_name "leo_visibility_A" description "Scenario satellite visibility"] \
        scenario [dict create duration_s 3600 step_s 1 orbit_type "LEO" environment "nominal"] \
        sensor [dict create fov_deg 12 altitude_m 550000 gain_db 18 pointing_mode "nadir"] \
        processing [dict create coverage_mode "footprint" export_access_windows 1 estimator "deterministic"] \
        io [dict create input_data "" output_dir "./runs/satellite"] \
        notes [dict create author "" tags "visibility,leo"]]
}

proc cfged::presetUnderwater {} {
    return [dict create \
        domain underwater \
        general [dict create case_name "uw_passive_01" description "Scenario underwater passive processing"] \
        scenario [dict create duration_s 300 fs_hz 96000 target_count 2 environment "sea_state_2"] \
        sensor [dict create center_freq_hz 25000 array_elements 16 gain_db 20 platform_speed_ms 3] \
        processing [dict create beamforming "delay_sum" detector "energy" threshold_mode "adaptive"] \
        io [dict create input_data "data/hydrophone_01.dat" output_dir "./runs/underwater"] \
        notes [dict create author "" tags "passive,test"]]
}

proc cfged::presetHDL {} {
    return [dict create \
        domain hdl \
        general [dict create case_name "tb_smoke_01" description "HDL smoke regression"] \
        scenario [dict create timescale "1ns/1ps" seed 1234 environment "sim"] \
        sensor [dict create dut_name "top_level_dut" clock_mhz 100 reset_cycles 10 interface_mode "axi_stream"] \
        processing [dict create suite "smoke" waves 1 coverage 0 checker_mode "basic"] \
        io [dict create input_data "" output_dir "./runs/hdl"] \
        notes [dict create author "" tags "hdl,smoke"]]
}

proc cfged::presetForDomain {domain} {
    switch -- $domain {
        radar      { return [cfged::presetRadar] }
        satellite  { return [cfged::presetSatellite] }
        underwater { return [cfged::presetUnderwater] }
        hdl        { return [cfged::presetHDL] }
        default    { return [cfged::presetRadar] }
    }
}

# --------------------------------------------------
# Utility
# --------------------------------------------------
proc cfged::fieldName {sec key} {
    return "${sec}.${key}"
}

proc cfged::ensureVar {name} {
    variable fieldVars
    if {![info exists fieldVars($name)]} {
        set fieldVars($name) ""
    }
}

proc cfged::log {msg} {
    variable ui
    set ts [clock format [clock seconds] -format "%H:%M:%S"]
    $ui(log) insert end "[$ts] $msg\n"
    $ui(log) see end
}

proc cfged::clearLog {} {
    variable ui
    $ui(log) delete 1.0 end
}

proc cfged::isNumber {x} {
    return [string is double -strict $x]
}

# --------------------------------------------------
# Config <-> UI
# --------------------------------------------------
proc cfged::loadConfigToUI {cfg} {
    variable currentDomain
    variable fieldVars

    if {[dict exists $cfg domain]} {
        set currentDomain [dict get $cfg domain]
    }

    set specs [cfged::fieldSpecsForDomain $currentDomain]
    foreach spec $specs {
        lassign $spec sec key label widgetType
        set name [cfged::fieldName $sec $key]
        cfged::ensureVar $name
        if {[dict exists $cfg $sec $key]} {
            set fieldVars($name) [dict get $cfg $sec $key]
        } else {
            set fieldVars($name) ""
        }
    }

    .top.domain set $currentDomain
    cfged::rebuildDomainTabs
}

proc cfged::collectConfigFromUI {} {
    variable currentDomain
    variable fieldVars

    set cfg [dict create domain $currentDomain]
    set specs [cfged::fieldSpecsForDomain $currentDomain]

    foreach spec $specs {
        lassign $spec sec key label widgetType
        set name [cfged::fieldName $sec $key]
        cfged::ensureVar $name
        dict set cfg $sec $key $fieldVars($name)
    }

    return $cfg
}

# --------------------------------------------------
# JSON writer minimale
# --------------------------------------------------
proc cfged::jsonEscape {s} {
    set s [string map [list "\\" "\\\\" "\"" "\\\"" "\n" "\\n" "\r" "\\r" "\t" "\\t"] $s]
    return $s
}

proc cfged::isNumericLiteral {s} {
    return [string is double -strict $s]
}

proc cfged::toJson {value {indent 0}} {
    if {[catch {dict size $value}]} {
        if {[cfged::isNumericLiteral $value]} {
            return $value
        }
        if {$value eq "true" || $value eq "false" || $value eq "null"} {
            return $value
        }
        return "\"[cfged::jsonEscape $value]\""
    }

    set spaces [string repeat " " $indent]
    set inner [string repeat " " [expr {$indent + 2}]]

    set parts {}
    foreach {k v} $value {
        lappend parts "${inner}\"[cfged::jsonEscape $k]\": [cfged::toJson $v [expr {$indent + 2}]]"
    }
    return "{\n[join $parts ",\n"]\n${spaces}}"
}

# --------------------------------------------------
# Validazione domain-aware
# --------------------------------------------------
proc cfged::validate {} {
    variable currentDomain
    variable fieldVars

    cfged::clearLog
    set ok 1

    foreach name {general.case_name io.output_dir} {
        set v [string trim $fieldVars($name)]
        if {$v eq ""} {
            cfged::log "ERROR: campo obbligatorio mancante: $name"
            set ok 0
        }
    }

    set numericFields {
        radar {
            scenario.duration_s scenario.fs_hz scenario.target_count
            sensor.fc_hz sensor.bandwidth_hz sensor.tx_power_w sensor.gain_db
            processing.integration_pulses
        }
        satellite {
            scenario.duration_s scenario.step_s
            sensor.fov_deg sensor.altitude_m sensor.gain_db
        }
        underwater {
            scenario.duration_s scenario.fs_hz scenario.target_count
            sensor.center_freq_hz sensor.array_elements sensor.gain_db sensor.platform_speed_ms
        }
        hdl {
            scenario.seed sensor.clock_mhz sensor.reset_cycles
        }
    }

    foreach name [dict get $numericFields $currentDomain] {
        if {[info exists fieldVars($name)]} {
            set v [string trim $fieldVars($name)]
            if {$v ne "" && ![cfged::isNumber $v]} {
                cfged::log "ERROR: il campo $name deve essere numerico"
                set ok 0
            }
        }
    }

    switch -- $currentDomain {
        radar {
            if {$fieldVars(sensor.tx_power_w) ne "" && $fieldVars(sensor.tx_power_w) <= 0} {
                cfged::log "ERROR: sensor.tx_power_w deve essere > 0"
                set ok 0
            }
        }
        satellite {
            if {$fieldVars(sensor.fov_deg) ne "" && ($fieldVars(sensor.fov_deg) <= 0 || $fieldVars(sensor.fov_deg) >= 180)} {
                cfged::log "ERROR: sensor.fov_deg deve stare tra 0 e 180"
                set ok 0
            }
        }
        underwater {
            if {$fieldVars(sensor.array_elements) ne "" && $fieldVars(sensor.array_elements) < 1} {
                cfged::log "ERROR: sensor.array_elements deve essere >= 1"
                set ok 0
            }
        }
        hdl {
            if {$fieldVars(sensor.clock_mhz) ne "" && $fieldVars(sensor.clock_mhz) <= 0} {
                cfged::log "ERROR: sensor.clock_mhz deve essere > 0"
                set ok 0
            }
        }
    }

    if {$ok} {
        cfged::log "OK: configurazione valida per dominio '$currentDomain'"
    }
    return $ok
}

# --------------------------------------------------
# File I/O
# --------------------------------------------------
proc cfged::newFile {} {
    variable currentFile
    variable currentDomain
    set currentFile ""
    set cfg [cfged::presetForDomain $currentDomain]
    cfged::loadConfigToUI $cfg
    wm title . "Config Editor"
    cfged::log "Nuova configurazione ($currentDomain)"
}

proc cfged::saveAs {} {
    variable currentFile
    set f [tk_getSaveFile \
        -title "Salva configurazione" \
        -defaultextension ".json" \
        -filetypes {{"JSON files" {.json}} {"All files" {*}}}]
    if {$f eq ""} { return }
    set currentFile $f
    cfged::saveFile
}

proc cfged::saveFile {} {
    variable currentFile

    if {$currentFile eq ""} {
        cfged::saveAs
        return
    }

    if {![cfged::validate]} {
        set ans [tk_messageBox -icon warning -type yesno -title "Validazione" \
            -message "La configurazione contiene errori. Salvare comunque?"]
        if {$ans ne "yes"} { return }
    }

    set cfg [cfged::collectConfigFromUI]
    set json [cfged::toJson $cfg]

    if {[catch {
        set ch [open $currentFile w]
        puts $ch $json
        close $ch
    } err]} {
        tk_messageBox -icon error -title "Errore" -message "Salvataggio fallito:\n$err"
        return
    }

    wm title . "Config Editor - [file tail $currentFile]"
    cfged::log "File salvato: $currentFile"
}

proc cfged::openFile {} {
    variable currentFile
    set f [tk_getOpenFile \
        -title "Apri configurazione" \
        -filetypes {{"JSON files" {.json}} {"All files" {*}}}]
    if {$f eq ""} { return }

    tk_messageBox -icon info -title "Nota" \
        -message "In questa V2 il salvataggio JSON è presente, ma il parsing in apertura non è ancora implementato.\n\nIl passo naturale della V3 è aggiungere import JSON completo."
    set currentFile $f
    wm title . "Config Editor - [file tail $currentFile]"
    cfged::log "Open richiesto per: $f"
}

# --------------------------------------------------
# UI domain-aware
# --------------------------------------------------
proc cfged::destroyNotebookTabs {} {
    if {[winfo exists .right.editor.nb]} {
        foreach tab [.right.editor.nb tabs] {
            .right.editor.nb forget $tab
        }
    }
    foreach child [winfo children .right.editor.nb] {
        destroy $child
    }
}

proc cfged::buildSectionFrame {parent section specs} {
    variable fieldVars
    ttk::frame $parent.$section -padding 10
    grid columnconfigure $parent.$section 1 -weight 1

    set row 0
    foreach spec $specs {
        lassign $spec sec key label widgetType values
        if {$sec ne $section} { continue }

        set name [cfged::fieldName $sec $key]
        cfged::ensureVar $name

        set lpath $parent.$section.l$row
        set wpath $parent.$section.w$row

        ttk::label $lpath -text $label

        if {$widgetType eq "combo"} {
            ttk::combobox $wpath \
                -textvariable cfged::fieldVars($name) \
                -values $values \
                -state readonly
        } else {
            ttk::entry $wpath -textvariable cfged::fieldVars($name)
        }

        grid $lpath -row $row -column 0 -sticky w -pady 4 -padx 4
        grid $wpath -row $row -column 1 -sticky ew -pady 4 -padx 4

        incr row
    }

    return $parent.$section
}

proc cfged::visibleSectionsForDomain {domain} {
    return {general scenario sensor processing io notes}
}

proc cfged::rebuildDomainTabs {} {
    variable currentDomain
    variable ui

    cfged::destroyNotebookTabs

    set specs [cfged::fieldSpecsForDomain $currentDomain]
    set sections [cfged::visibleSectionsForDomain $currentDomain]

    $ui(sectionList) delete 0 end
    foreach s $sections {
        $ui(sectionList) insert end $s
        set frame [cfged::buildSectionFrame .right.editor.nb $s $specs]
        .right.editor.nb add $frame -text [string totitle $s]
    }

    if {[llength $sections] > 0} {
        .right.editor.nb select 0
        $ui(sectionList) selection set 0
    }
}

proc cfged::onDomainChanged {} {
    variable currentDomain
    set cfg [cfged::presetForDomain $currentDomain]
    cfged::loadConfigToUI $cfg
    cfged::log "Dominio selezionato: $currentDomain"
}

proc cfged::buildUI {} {
    variable ui
    variable currentDomain

    wm title . "Config Editor V2"
    wm geometry . 1150x760
    wm minsize . 950 620
    ttk::style theme use clam

    ttk::frame .top -padding 6
    pack .top -fill x

    ttk::button .top.new    -text "Nuovo" -command cfged::newFile
    ttk::button .top.open   -text "Apri" -command cfged::openFile
    ttk::button .top.save   -text "Salva" -command cfged::saveFile
    ttk::button .top.saveas -text "Salva come" -command cfged::saveAs
    ttk::button .top.valid  -text "Valida" -command cfged::validate

    ttk::label .top.domainL -text "Dominio:"
    ttk::combobox .top.domain -state readonly \
        -values {radar satellite underwater hdl} \
        -textvariable cfged::currentDomain
    ttk::button .top.loadPreset -text "Carica preset" -command {
        set cfg [cfged::presetForDomain $cfged::currentDomain]
        cfged::loadConfigToUI $cfg
        cfged::log "Preset ricaricato: $cfged::currentDomain"
    }

    pack .top.new .top.open .top.save .top.saveas .top.valid -side left -padx 3
    pack .top.loadPreset -side right -padx 3
    pack .top.domain -side right -padx 3
    pack .top.domainL -side right -padx 3

    ttk::panedwindow .pw -orient horizontal
    pack .pw -fill both -expand 1

    ttk::frame .left -padding 6
    ttk::frame .right -padding 6
    .pw add .left -weight 1
    .pw add .right -weight 4

    ttk::labelframe .left.box -text "Sezioni" -padding 6
    pack .left.box -fill both -expand 1

    set ui(sectionList) [listbox .left.box.lb -exportselection 0]
    pack $ui(sectionList) -fill both -expand 1

    ttk::labelframe .right.editor -text "Editor parametri" -padding 6
    pack .right.editor -fill both -expand 1

    ttk::notebook .right.editor.nb
    pack .right.editor.nb -fill both -expand 1

    bind $ui(sectionList) <<ListboxSelect>> {
        set idx [lindex [%W curselection] 0]
        if {$idx ne ""} {
            .right.editor.nb select $idx
        }
    }

    bind .top.domain <<ComboboxSelected>> {cfged::onDomainChanged}

    ttk::labelframe .right.logbox -text "Validazione / messaggi" -padding 6
    pack .right.logbox -fill both -expand 1 -pady 8

    set ui(log) [text .right.logbox.txt -height 12 -wrap word]
    ttk::scrollbar .right.logbox.sb -orient vertical -command "$ui(log) yview"
    $ui(log) configure -yscrollcommand ".right.logbox.sb set"

    grid $ui(log) -row 0 -column 0 -sticky nsew
    grid .right.logbox.sb -row 0 -column 1 -sticky ns
    grid rowconfigure .right.logbox 0 -weight 1
    grid columnconfigure .right.logbox 0 -weight 1
}

cfged::buildUI
cfged::loadConfigToUI [cfged::presetRadar]
cfged::log "Config Editor V2 inizializzato"
cfged::log "Modalità domain-aware attiva"