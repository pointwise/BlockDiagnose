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
  label .b.logo -image [cadenceLogo] -relief flat
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
# Cadence logo picture data

proc cadenceLogo { } {
  set logoData "
R0lGODlhgAAYAPQfAI6MjDEtLlFOT8jHx7e2tv39/RYSE/Pz8+Tj46qoqHl3d+vq62ZjY/n4+NT
T0+gXJ/BhbN3d3fzk5vrJzR4aG3Fubz88PVxZWp2cnIOBgiIeH769vtjX2MLBwSMfIP///yH5BA
EAAB8AIf8LeG1wIGRhdGF4bXD/P3hwYWNrZXQgYmVnaW49Iu+7vyIgaWQ9Ilc1TTBNcENlaGlIe
nJlU3pOVGN6a2M5ZCI/PiA8eDp4bXBtdGEgeG1sbnM6eD0iYWRvYmU6bnM6bWV0YS8iIHg6eG1w
dGs9IkFkb2JlIFhNUCBDb3JlIDUuMC1jMDYxIDY0LjE0MDk0OSwgMjAxMC8xMi8wNy0xMDo1Nzo
wMSAgICAgICAgIj48cmRmOlJERiB4bWxuczpyZGY9Imh0dHA6Ly93d3cudy5vcmcvMTk5OS8wMi
8yMi1yZGYtc3ludGF4LW5zIyI+IDxyZGY6RGVzY3JpcHRpb24gcmY6YWJvdXQ9IiIg/3htbG5zO
nhtcE1NPSJodHRwOi8vbnMuYWRvYmUuY29tL3hhcC8xLjAvbW0vIiB4bWxuczpzdFJlZj0iaHR0
cDovL25zLmFkb2JlLmNvbS94YXAvMS4wL3NUcGUvUmVzb3VyY2VSZWYjIiB4bWxuczp4bXA9Imh
0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC8iIHhtcE1NOk9yaWdpbmFsRG9jdW1lbnRJRD0idX
VpZDoxMEJEMkEwOThFODExMUREQTBBQzhBN0JCMEIxNUM4NyB4bXBNTTpEb2N1bWVudElEPSJ4b
XAuZGlkOkIxQjg3MzdFOEI4MTFFQjhEMv81ODVDQTZCRURDQzZBIiB4bXBNTTpJbnN0YW5jZUlE
PSJ4bXAuaWQ6QjFCODczNkZFOEI4MTFFQjhEMjU4NUNBNkJFRENDNkEiIHhtcDpDcmVhdG9yVG9
vbD0iQWRvYmUgSWxsdXN0cmF0b3IgQ0MgMjMuMSAoTWFjaW50b3NoKSI+IDx4bXBNTTpEZXJpZW
RGcm9tIHN0UmVmOmluc3RhbmNlSUQ9InhtcC5paWQ6MGE1NjBhMzgtOTJiMi00MjdmLWE4ZmQtM
jQ0NjMzNmNjMWI0IiBzdFJlZjpkb2N1bWVudElEPSJ4bXAuZGlkOjBhNTYwYTM4LTkyYjItNDL/
N2YtYThkLTI0NDYzMzZjYzFiNCIvPiA8L3JkZjpEZXNjcmlwdGlvbj4gPC9yZGY6UkRGPiA8L3g
6eG1wbWV0YT4gPD94cGFja2V0IGVuZD0iciI/PgH//v38+/r5+Pf29fTz8vHw7+7t7Ovp6Ofm5e
Tj4uHg397d3Nva2djX1tXU09LR0M/OzczLysnIx8bFxMPCwcC/vr28u7q5uLe2tbSzsrGwr66tr
KuqqainpqWko6KhoJ+enZybmpmYl5aVlJOSkZCPjo2Mi4qJiIeGhYSDgoGAf359fHt6eXh3dnV0
c3JxcG9ubWxramloZ2ZlZGNiYWBfXl1cW1pZWFdWVlVUU1JRUE9OTUxLSklIR0ZFRENCQUA/Pj0
8Ozo5ODc2NTQzMjEwLy4tLCsqKSgnJiUkIyIhIB8eHRwbGhkYFxYVFBMSERAPDg0MCwoJCAcGBQ
QDAgEAACwAAAAAgAAYAAAF/uAnjmQpTk+qqpLpvnAsz3RdFgOQHPa5/q1a4UAs9I7IZCmCISQwx
wlkSqUGaRsDxbBQer+zhKPSIYCVWQ33zG4PMINc+5j1rOf4ZCHRwSDyNXV3gIQ0BYcmBQ0NRjBD
CwuMhgcIPB0Gdl0xigcNMoegoT2KkpsNB40yDQkWGhoUES57Fga1FAyajhm1Bk2Ygy4RF1seCjw
vAwYBy8wBxjOzHq8OMA4CWwEAqS4LAVoUWwMul7wUah7HsheYrxQBHpkwWeAGagGeLg717eDE6S
4HaPUzYMYFBi211FzYRuJAAAp2AggwIM5ElgwJElyzowAGAUwQL7iCB4wEgnoU/hRgIJnhxUlpA
SxY8ADRQMsXDSxAdHetYIlkNDMAqJngxS47GESZ6DSiwDUNHvDd0KkhQJcIEOMlGkbhJlAK/0a8
NLDhUDdX914A+AWAkaJEOg0U/ZCgXgCGHxbAS4lXxketJcbO/aCgZi4SC34dK9CKoouxFT8cBNz
Q3K2+I/RVxXfAnIE/JTDUBC1k1S/SJATl+ltSxEcKAlJV2ALFBOTMp8f9ihVjLYUKTa8Z6GBCAF
rMN8Y8zPrZYL2oIy5RHrHr1qlOsw0AePwrsj47HFysrYpcBFcF1w8Mk2ti7wUaDRgg1EISNXVwF
lKpdsEAIj9zNAFnW3e4gecCV7Ft/qKTNP0A2Et7AUIj3ysARLDBaC7MRkF+I+x3wzA08SLiTYER
KMJ3BoR3wzUUvLdJAFBtIWIttZEQIwMzfEXNB2PZJ0J1HIrgIQkFILjBkUgSwFuJdnj3i4pEIlg
eY+Bc0AGSRxLg4zsblkcYODiK0KNzUEk1JAkaCkjDbSc+maE5d20i3HY0zDbdh1vQyWNuJkjXnJ
C/HDbCQeTVwOYHKEJJwmR/wlBYi16KMMBOHTnClZpjmpAYUh0GGoyJMxya6KcBlieIj7IsqB0ji
5iwyyu8ZboigKCd2RRVAUTQyBAugToqXDVhwKpUIxzgyoaacILMc5jQEtkIHLCjwQUMkxhnx5I/
seMBta3cKSk7BghQAQMeqMmkY20amA+zHtDiEwl10dRiBcPoacJr0qjx7Ai+yTjQvk31aws92JZ
Q1070mGsSQsS1uYWiJeDrCkGy+CZvnjFEUME7VaFaQAcXCCDyyBYA3NQGIY8ssgU7vqAxjB4EwA
DEIyxggQAsjxDBzRagKtbGaBXclAMMvNNuBaiGAAA7"

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
