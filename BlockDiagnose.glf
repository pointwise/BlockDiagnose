#############################################################################
#
# (C) 2021 Cadence Design Systems, Inc. All rights reserved worldwide.
#
# This sample script is not supported by Cadence Design Systems, Inc.
# It is provided freely for demonstration purposes only.
# SEE THE WARRANTY DISCLAIMER AT THE BOTTOM OF THIS FILE.
#
#############################################################################

# --------------------------------------------------------------------------
#
# BlockDiagnose.glf
#
# Script with Tk interface to generate a block metric quality report.
#
# --------------------------------------------------------------------------

# Load Pointwise Glyph package and Tk
package require PWI_Glyph 2

# Prerequisite: Ensure at least one block in model
if {[pw::Grid getCount -type pw::Block] == 0} {
  puts "No blocks in current system"
  exit 1
}

# Load Tk
pw::Script loadTk

# --------------------------------------------------------------------------
# Initialize variables

proc addOpt { k l f t v {isInt 0} } {
  global opt order lbl fun min max int typ val
  lappend order $k
  set opt($k) 0
  set lbl($k) $l
  set fun($k) $f
  set min($k) ""
  set max($k) ""
  set int($k) $isInt
  set typ($k) $v
  if { [lsearch [split $t "|"] S] >= 0 } {
    lappend val(Structured) $k
  }
  if { [lsearch [split $t "|"] U] >= 0 } {
    lappend val(Unstructured) $k
  }
  if { [lsearch [split $t "|"] E] >= 0 } {
    lappend val(Extruded) $k
  }
}

addOpt iSize       "I Size"               BlockLengthI        "S"     D 1
addOpt jSize       "J Size"               BlockLengthJ        "S"     D 1
addOpt kSize       "K Size"               BlockLengthK        "S|E"   D 1
addOpt volume      "Volume"               BlockVolume         "U|S|E" F
addOpt volRatio    "Volume Ratio"         BlockVolumeRatio    "U|S|E" F
addOpt iRatio      "I Ratio"              BlockLengthRatioI   "S"     F
addOpt jRatio      "J Ratio"              BlockLengthRatioJ   "S"     F
addOpt kRatio      "K Ratio"              BlockLengthRatioK   "S|E"   F
addOpt aspRatio    "Aspect Ratio"         BlockAspectRatio    "S|U|E" F
addOpt iSmooth     "I Smoothness"         BlockSmoothnessI    "S"     F
addOpt jSmooth     "J Smoothness"         BlockSmoothnessJ    "S"     F
addOpt kSmooth     "K Smoothness"         BlockSmoothnessK    "S|E"   F
addOpt minAlphSkew "Min Alpha Skewness"   BlockMinimumAngle   "S|U|E" F
addOpt maxAlphSkew "Max Alpha Skewness"   BlockMaximumAngle   "S|U|E" F
addOpt jacobians   "Jacobians"            BlockJacobian       "S|E"   F
addOpt eqAngSkew   "Equi-Angle Skewness"  BlockSkewEquiangle  "S|U|E" F
addOpt eqVolSkew   "Equi-Volume Skewness" BlockSkewEquivolume "U"     F

set color(Valid)   SystemWindow
set color(Invalid) MistyRose
set io(useFile) 0
set io(ch) ""
set io(dir) ""

# --------------------------------------------------------------------------
# Browse for report (output) file name

proc browseFile {} {
  global io
  set io(dir) [tk_getSaveFile -defaultextension .txt -filetypes \
    {{{Text Files} {.txt}} {{Log Files} {.log}} {{All Files} *}}]
}

# --------------------------------------------------------------------------
# Open the report file for writing

proc openFile { } {
    global io
    set ret 1
    if $io(useFile) {
      if { ![file exists $io(dir)] || [file writable $io(dir)] } {
        set io(ch) [open $io(dir) w]
      } else {
        return -code error "Could not open $io(dir) for writing"
      }
    } else {
      set io(ch) "stdout"
    }
}

# --------------------------------------------------------------------------
# Write an 80-column centered string with optional string at start/end

proc writeCentered { s {p ""} } {
  global io
  set l1 [expr 40 + ([string length $s] / 2) - [string length $p]]
  set l2 [expr 80 - $l1 - [string length $p]]
  if [string length $p] {
    puts $io(ch) [format "%s%${l1}s%${l2}s" $p $s $p]
  } else {
    puts $io(ch) [format "%${l1}s" $s]
  }
}

# --------------------------------------------------------------------------
# Write report main header

proc writeMainHeader {} {
  global io

  set stars40 "****************************************"

  puts $io(ch) [format "%s%s" $stars40 $stars40]
  puts $io(ch) [format "%2.2s%76s%2.2s" $stars40 " " $stars40]
  writeCentered "Block Diagnostics" "**"
  puts $io(ch) [format "%2.2s%76s%2.2s" $stars40 " " $stars40]
  puts $io(ch) [format "%s%s" $stars40 $stars40]
}

# --------------------------------------------------------------------------
# Write report section header

proc writeSectionHeader { name min max } {
  global io

  set dashes40 "========================================"

  puts $io(ch) ""
  puts $io(ch) [format "%s%s" $dashes40 $dashes40]
  writeCentered $name
  puts $io(ch) [format "%s%s" $dashes40 $dashes40]

  set line ""
  foreach m "$min $max" l {"Minimum" "Maximum"} {
    if [string is integer -strict $m] {
      set sub [format "$l Range Value: %9d" $m]
    } elseif [string is double -strict] {
      set sub [format "$l Range Value: %9.4g" $m]
    } else {
      set sub [format "$l Range Value: %9s" $m]
    }
    set line [format "%s%-40s" $line $sub]
  }
  puts $io(ch) "$line"
  puts $io(ch) ""

  set dashes "--------------------"
  puts $io(ch) [format "%-20s %9s %9s %9s %9s %9s %9s" \
    "Block Name" "Min" "Avg" "Max" "Below" "In Range" "Above"]
  puts $io(ch) [format "%-20s %9.9s %9.9s %9.9s %9.9s %9.9s %9.9s" \
    $dashes $dashes $dashes $dashes $dashes $dashes $dashes]
}

# --------------------------------------------------------------------------
# Write report data line

proc writeBody { name min avg max below inRange above } {
  global io

  puts $io(ch) [format "%-20s %9.4g %9.4g %9.4g %9.4g %9.4g %9.4g" \
    [string range $name 0 19] $min $avg $max $below $inRange $above]
}

# --------------------------------------------------------------------------
# Write report totals line

proc writeTotals {min avg max below inRange above} {
  global io

  set dashes "--------------------"
  puts $io(ch) [format "%-20s %9.9s %9.9s %9.9s %9.9s %9.9s %9.9s" \
    $dashes $dashes $dashes $dashes $dashes $dashes $dashes]
  puts $io(ch) [format "%-20s %9.4g %9.4g %9.4g %9d %9d %9d" \
    "Total" $min $avg $max $below $inRange $above]
}

# --------------------------------------------------------------------------
# Write extra Jacobian data

proc writeJacobianCounts { pos posSkew zero negSkew neg {zeroIsNone 0}} {
  global io

  if $pos {
    puts $io(ch) [format "%20s %39s %9d" "(positive)" "" $pos]
  }
  if $posSkew {
    puts $io(ch) [format "%20s %39s %9d" "(positive skew)" "" $posSkew]
  }
  if $zero {
    puts $io(ch) [format "%20s %39s %9d" "(zero)" "" $zero]
  }
  if $negSkew {
    puts $io(ch) [format "%20s %39s %9d" "(negative skew)" "" $negSkew]
  }
  if $neg {
    puts $io(ch) [format "%20s %39s %9d" "(negative)" "" $neg]
  }
}

# --------------------------------------------------------------------------
# Perform block examination for a single metric

proc doBlockExam { key } {
  global io lbl fun min max int val

  set lmin $min($key)
  set lmax $max($key)
  set zeroIsNone $int($key)

  # If min and/or max value not specified set to n/a
  if { [string length $lmin] == 0 || ($zeroIsNone && $lmin == 0) } {
    set lmin "None"
  }
  if { [string length $lmax] == 0 || ($zeroIsNone && $lmax == 0) } {
    set lmax "None"
  }

  writeSectionHeader $lbl($key) $lmin $lmax

  set examBlocks [list]

  set exam [pw::Examine create $fun($key)]
  $exam setRangeLimits $lmin $lmax

  foreach block [pw::Grid getAll -type pw::Block] {
    $exam removeAll
    if { ([lsearch $val(Structured) $key] >= 0 && \
          [$block isOfType pw::BlockStructured]) || \
         ([lsearch $val(Unstructured) $key] >= 0 && \
          [$block isOfType pw::BlockUnstructured]) || \
         ([lsearch $val(Extruded) $key] >= 0 && \
          [$block isOfType pw::BlockExtruded]) } {
      if { [catch { $exam addEntity $block } msg] } {
        puts $io(ch) "Could not examine block \"[$block getName]\": $msg"
        continue
      }
      lappend examBlocks $block
      $exam examine
      writeBody [$block getName] \
        [$exam getMinimum] [$exam getAverage] [$exam getMaximum] \
        [$exam getBelowRange] [$exam getInRange] [$exam getAboveRange]
      if { $key eq "jacobians" } {
        writeJacobianCounts [$exam getCategoryCount Positive] \
            [$exam getCategoryCount PositiveSkew] \
            [$exam getCategoryCount Zero] \
            [$exam getCategoryCount NegativeSkew] \
            [$exam getCategoryCount Negative]
      }
    }
  }

  $exam removeAll
  if { [catch { $exam addEntity $examBlocks } msg] } {
    puts $io(ch) "Could not examine all blocks: $msg"
  } else {
    $exam examine
    writeTotals \
      [$exam getMinimum] [$exam getAverage] [$exam getMaximum] \
      [$exam getBelowRange] [$exam getInRange] [$exam getAboveRange]
    if { $key eq "jacobians" } {
      writeJacobianCounts [$exam getCategoryCount Positive] \
          [$exam getCategoryCount PositiveSkew] \
          [$exam getCategoryCount Zero] \
          [$exam getCategoryCount NegativeSkew] \
          [$exam getCategoryCount Negative]
    }
  }

  $exam delete
}

# --------------------------------------------------------------------------
# Run block examination report

proc doBlockDiagnose {} {
  global io opt order

  if [catch { openFile } msg] {
    return -code error $msg
  }

  writeMainHeader

  foreach o $order {
    if $opt($o) {
      doBlockExam $o
    }
  }

  # If writing to file close it
  if $io(useFile) {
    close $io(ch)
  }
  exit
}

# --------------------------------------------------------------------------
# Validate an entry field as a floating point number using a regular
# expression

proc validDbl { w value } {
  global color
  if { [string length $value] == 0 || \
    [regexp {^[+-]?\d*\.?\d+(e-?\d+)?$} $value] } {
    $w configure -background $color(Valid)
  } else {
    $w configure -background $color(Invalid)
  }
  updateButtons
  return 1
}

# --------------------------------------------------------------------------
# Validate an entry field as a grid dimension (positive, non-zero integer)

proc validDim { w value } {
  global color
  if { [string length $value] == 0 || [regexp {^\d+?$} $value] } {
    $w configure -background $color(Valid)
  } else {
    $w configure -background $color(Invalid)
  }
  updateButtons
  return 1
}

# --------------------------------------------------------------------------
# Return whether an entry field is marked valid or not (by background color)

proc buttonState { chk } {
  global opt color
  return [expr !$opt($chk) || \
      ([string equal [.t.${chk}Min cget -background] $color(Valid)] && \
      [string equal [.t.${chk}Max cget -background] $color(Valid)])]
}

# --------------------------------------------------------------------------
# Check for valid input and enable the action buttons

proc updateButtons { } {
  global opt
  set enabled 0
  foreach e [array names opt] {
    set enabled [buttonState $e]
    if { ! $enabled } break
  }

  if $enabled {
    .b.run configure -state normal
  } else {
    .b.run configure -state disabled
  }
}

# --------------------------------------------------------------------------
# Enable/disable a pair of min/max entry fields for the given key

proc setEntryState { chk } {
  global opt min max
  if $opt($chk) {
    .t.${chk}Min configure -state normal
    .t.${chk}Max configure -state normal
  } else {
    .t.${chk}Min configure -state disabled
    .t.${chk}Max configure -state disabled
  }
}

# --------------------------------------------------------------------------
# Enable/disable entry fields based on dialog settings

proc optChanged { } {
  global opt io

  foreach e [array names opt] {
    setEntryState $e
  }

  if $io(useFile) {
    .d.direct configure -state normal
    .d.browse configure -state normal
  } else {
    .d.direct configure -state disabled
    .d.browse configure -state disabled
  }
}

# --------------------------------------------------------------------------
# Create the Tk window

proc makeWindow { } {
  global order opt val min max io lbl typ logoData

  wm title . "Block Diagnostics"

  frame .t
  frame .d
  frame .b -borderwidth 2 -relief sunken
  frame .sp1 -bd 1 -height 2 -relief sunken
  frame .sp2 -bd 1 -height 2 -relief sunken

  set fontSize [font actual TkCaptionFont -size]
  set titleFont [font create -family [font actual TkCaptionFont -family] \
      -weight bold -size [expr {int(1.5 * $fontSize)}]]
  set headerFont [font create -family [font actual TkCaptionFont -family] \
      -weight bold -size [expr {int(1.25 * $fontSize)}]]

  label .title -text "Block Diagnostics" -font $titleFont
  label .t.funct -text Function -font headerFont
  label .t.min -text "Min Range" -font headerFont
  label .t.max -text "Max Range" -font headerFont

  foreach o [array names opt] {
    checkbutton .t.$o -text $lbl($o) -variable opt($o) -command optChanged
    entry .t.${o}Min -textvariable min($o) -width 20
    entry .t.${o}Max -textvariable max($o) -width 20
    switch $typ($o) {
      D {
        .t.${o}Min configure -validate focus -vcmd "validDim %W %P"
        .t.${o}Max configure -validate focus -vcmd "validDim %W %P"
      }
      F {
        .t.${o}Min configure -validate focus -vcmd "validDbl %W %P"
        .t.${o}Max configure -validate focus -vcmd "validDbl %W %P"
      }
    }
  }

  label .d.lfn -text "Output:"

  radiobutton .d.console -text Console -variable io(useFile) -value 0 \
    -command optChanged
  radiobutton .d.file -text File -variable io(useFile) -value 1 \
    -command optChanged

  entry .d.direct -textvariable io(dir) -state disabled -width 64
  button .d.browse -text ... -width -3 -state disabled -command browseFile
  label .b.logo -image [pwLogo] -relief flat
  label .b.space -text "" -width 35
  button .b.cancel -text Cancel -command exit -width -12
  button .b.run -text Run -command doBlockDiagnose -width -12

  # Disable certain checkboxes depending on block types in model
  set haveStr [expr [pw::Grid getCount -type pw::BlockStructured] > 0]
  set haveUns [expr [pw::Grid getCount -type pw::BlockUnstructured] > 0]
  set haveExt [expr [pw::Grid getCount -type pw::BlockExtruded] > 0]
  foreach o [array names opt] {
    if { ! (($haveStr && [lsearch $val(Structured) $o] >= 0) || \
            ($haveUns && [lsearch $val(Unstructured) $o] >= 0) || \
            ($haveExt && [lsearch $val(Extruded) $o] >= 0)) } {
      .t.$o configure -state disabled
    }
  }

  pack .title -side top -fill x
  pack .sp1 -pady 4 -side top -fill x
  pack .t -side top -fill both -expand 1

  grid .t.funct .t.min .t.max
  foreach o $order {
    grid .t.$o .t.${o}Min .t.${o}Max -padx 2 -sticky w
  }

  pack .sp2 -pady 4 -side top -fill x
  pack .d -side top -fill x -pady 4
  grid .d.lfn .d.console -padx 3 -sticky w
  grid x .d.file .d.direct .d.browse -padx 3 -sticky w
  grid configure .d.direct -sticky ew
  grid columnconfigure .d 2 -weight 1

  pack .b -side bottom -fill x
  pack .b.logo -side left
  pack .b.run .b.cancel -side right -pady 4 -padx 2

  bind . <Return> { .b.run invoke }
  bind . <Escape> { .b.cancel invoke }

  optChanged
  updateButtons
}

# --------------------------------------------------------------------------
# Pointwise logo picture data

proc pwLogo { } {
  set logoData "
R0lGODlheAAYAIcAAAAAAAICAgUFBQkJCQwMDBERERUVFRkZGRwcHCEhISYmJisrKy0tLTIyMjQ0
NDk5OT09PUFBQUVFRUpKSk1NTVFRUVRUVFpaWlxcXGBgYGVlZWlpaW1tbXFxcXR0dHp6en5+fgBi
qQNkqQVkqQdnrApmpgpnqgpprA5prBFrrRNtrhZvsBhwrxdxsBlxsSJ2syJ3tCR2siZ5tSh6tix8
ti5+uTF+ujCAuDODvjaDvDuGujiFvT6Fuj2HvTyIvkGKvkWJu0yUv2mQrEOKwEWNwkaPxEiNwUqR
xk6Sw06SxU6Uxk+RyVKTxlCUwFKVxVWUwlWWxlKXyFOVzFWWyFaYyFmYx16bwlmZyVicyF2ayFyb
zF2cyV2cz2GaxGSex2GdymGezGOgzGSgyGWgzmihzWmkz22iymyizGmj0Gqk0m2l0HWqz3asznqn
ynuszXKp0XKq1nWp0Xaq1Hes0Xat1Hmt1Xyt0Huw1Xux2IGBgYWFhYqKio6Ojo6Xn5CQkJWVlZiY
mJycnKCgoKCioqKioqSkpKampqmpqaurq62trbGxsbKysrW1tbi4uLq6ur29vYCu0YixzYOw14G0
1oaz14e114K124O03YWz2Ie12oW13Im10o621Ii22oi23Iy32oq52Y252Y+73ZS51Ze81JC625G7
3JG825K83Je72pW93Zq92Zi/35G+4aC90qG+15bA3ZnA3Z7A2pjA4Z/E4qLA2KDF3qTA2qTE3avF
36zG3rLM3aPF4qfJ5KzJ4LPL5LLM5LTO4rbN5bLR6LTR6LXQ6r3T5L3V6cLCwsTExMbGxsvLy8/P
z9HR0dXV1dbW1tjY2Nra2tzc3N7e3sDW5sHV6cTY6MnZ79De7dTg6dTh69Xi7dbj7tni793m7tXj
8Nbk9tjl9N3m9N/p9eHh4eTk5Obm5ujo6Orq6u3t7e7u7uDp8efs8uXs+Ozv8+3z9vDw8PLy8vL0
9/b29vb5+/f6+/j4+Pn6+/r6+vr6/Pn8/fr8/Pv9/vz8/P7+/gAAACH5BAMAAP8ALAAAAAB4ABgA
AAj/AP8JHEiwoMGDCBMqXMiwocOHECNKnEixosWLGDNqZCioo0dC0Q7Sy2btlitisrjpK4io4yF/
yjzKRIZPIDSZOAUVmubxGUF88Aj2K+TxnKKOhfoJdOSxXEF1OXHCi5fnTx5oBgFo3QogwAalAv1V
yyUqFCtVZ2DZceOOIAKtB/pp4Mo1waN/gOjSJXBugFYJBBflIYhsq4F5DLQSmCcwwVZlBZvppQtt
D6M8gUBknQxA879+kXixwtauXbhheFph6dSmnsC3AOLO5TygWV7OAAj8u6A1QEiBEg4PnA2gw7/E
uRn3M7C1WWTcWqHlScahkJ7NkwnE80dqFiVw/Pz5/xMn7MsZLzUsvXoNVy50C7c56y6s1YPNAAAC
CYxXoLdP5IsJtMBWjDwHHTSJ/AENIHsYJMCDD+K31SPymEFLKNeM880xxXxCxhxoUKFJDNv8A5ts
W0EowFYFBFLAizDGmMA//iAnXAdaLaCUIVtFIBCAjP2Do1YNBCnQMwgkqeSSCEjzzyJ/BFJTQfNU
WSU6/Wk1yChjlJKJLcfEgsoaY0ARigxjgKEFJPec6J5WzFQJDwS9xdPQH1sR4k8DWzXijwRbHfKj
YkFO45dWFoCVUTqMMgrNoQD08ckPsaixBRxPKFEDEbEMAYYTSGQRxzpuEueTQBlshc5A6pjj6pQD
wf9DgFYP+MPHVhKQs2Js9gya3EB7cMWBPwL1A8+xyCYLD7EKQSfEF1uMEcsXTiThQhmszBCGC7G0
QAUT1JS61an/pKrVqsBttYxBxDGjzqxd8abVBwMBOZA/xHUmUDQB9OvvvwGYsxBuCNRSxidOwFCH
J5dMgcYJUKjQCwlahDHEL+JqRa65AKD7D6BarVsQM1tpgK9eAjjpa4D3esBVgdFAB4DAzXImiDY5
vCFHESko4cMKSJwAxhgzFLFDHEUYkzEAG6s6EMgAiFzQA4rBIxldExBkr1AcJzBPzNDRnFCKBpTd
gCD/cKKKDFuYQoQVNhhBBSY9TBHCFVW4UMkuSzf/fe7T6h4kyFZ/+BMBXYpoTahB8yiwlSFgdzXA
5JQPIDZCW1FgkDVxgGKCFCywEUQaKNitRA5UXHGFHN30PRDHHkMtNUHzMAcAA/4gwhUCsB63uEF+
bMVB5BVMtFXWBfljBhhgbCFCEyI4EcIRL4ChRgh36LBJPq6j6nS6ISPkslY0wQbAYIr/ahCeWg2f
ufFaIV8QNpeMMAkVlSyRiRNb0DFCFlu4wSlWYaL2mOp13/tY4A7CL63cRQ9aEYBT0seyfsQjHedg
xAG24ofITaBRIGTW2OJ3EH7o4gtfCIETRBAFEYRgC06YAw3CkIqVdK9cCZRdQgCVAKWYwy/FK4i9
3TYQIboE4BmR6wrABBCUmgFAfgXZRxfs4ARPPCEOZJjCHVxABFAA4R3sic2bmIbAv4EvaglJBACu
IxAMAKARBrFXvrhiAX8kEWVNHOETE+IPbzyBCD8oQRZwwIVOyAAXrgkjijRWxo4BLnwIwUcCJvgP
ZShAUfVa3Bz/EpQ70oWJC2mAKDmwEHYAIxhikAQPeOCLdRTEAhGIQKL0IMoGTGMgIBClA9QxkA3U
0hkKgcy9HHEQDcRyAr0ChAWWucwNMIJZ5KilNGvpADtt5JrYzKY2t8nNbnrzm+B8SEAAADs="

  return [image create photo -format GIF -data $logoData]
}

makeWindow

tkwait window .

# END SCRIPT

#############################################################################
#
# This file is licensed under the Cadence Public License Version 1.0 (the
# "License"), a copy of which is found in the included file named "LICENSE",
# and is distributed "AS IS." TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE
# LAW, CADENCE DISCLAIMS ALL WARRANTIES AND IN NO EVENT SHALL BE LIABLE TO
# ANY PARTY FOR ANY DAMAGES ARISING OUT OF OR RELATING TO USE OF THIS FILE.
# Please see the License for the full text of applicable terms.
#
#############################################################################
