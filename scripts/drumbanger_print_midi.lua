-- LMS: Print DroneMIDI2 Pattern to MIDI Item
-- Run as background ReaScript (check "Run in background").
-- Click PRINT in DroneMIDI2 to stamp the active pattern as a MIDI item at the edit cursor.
-- Also works as a one-shot: run from Actions without background mode.

-- Scale tables (same as DroneMIDI2 @init)
local SCALES = {}
for i = 0, 23 do SCALES[0*24+i] = i end
local maj = {0,2,4,5,7,9,11,12,14,16,17,19,21,23,24,26,28,29,31,33,35,36,38,40}
for i = 0, 23 do SCALES[1*24+i] = maj[i+1] end
local mn = {0,2,3,5,7,8,10,12,14,15,17,19,20,22,24,26,27,29,31,32,34,36,38,39}
for i = 0, 23 do SCALES[2*24+i] = mn[i+1] end
local pmaj = {0,2,4,7,9,12,14,16,19,21,24,26,28,31,33,36,38,40,43,45,48,50,52,55}
for i = 0, 23 do SCALES[3*24+i] = pmaj[i+1] end
local pmin = {0,3,5,7,10,12,15,17,19,22,24,27,29,31,34,36,39,41,43,46,48,51,53,55}
for i = 0, 23 do SCALES[4*24+i] = pmin[i+1] end
local blu = {0,3,5,6,7,10,12,15,17,18,19,22,24,27,29,30,31,34,36,39,41,42,43,46}
for i = 0, 23 do SCALES[5*24+i] = blu[i+1] end
local dor = {0,2,3,5,7,9,10,12,14,15,17,19,21,22,24,26,27,29,31,33,34,36,38,39}
for i = 0, 23 do SCALES[6*24+i] = dor[i+1] end
local mxl = {0,2,4,5,7,9,10,12,14,16,17,19,21,22,24,26,28,29,31,33,34,36,38,40}
for i = 0, 23 do SCALES[7*24+i] = mxl[i+1] end

reaper.gmem_attach("DrumBanger")

local function build_notes(pad_idx, vel, root, scale_id, chord_mode, oct_offset)
  local notes = {}
  local base = root + oct_offset * 12
  local note = base + (SCALES[scale_id * 24 + pad_idx] or 0)

  if chord_mode == 1 then
    notes[#notes+1] = {note = note, vel = vel}
  elseif chord_mode == 2 then
    notes[#notes+1] = {note = note, vel = vel}
    notes[#notes+1] = {note = base + (SCALES[scale_id*24 + pad_idx + 2] or 0), vel = vel}
    notes[#notes+1] = {note = base + (SCALES[scale_id*24 + pad_idx + 4] or 0), vel = vel}
  elseif chord_mode == 3 then
    notes[#notes+1] = {note = note, vel = vel}
    notes[#notes+1] = {note = base + (SCALES[scale_id*24 + pad_idx + 2] or 0), vel = vel}
    notes[#notes+1] = {note = base + (SCALES[scale_id*24 + pad_idx + 4] or 0), vel = vel}
    notes[#notes+1] = {note = base + (SCALES[scale_id*24 + pad_idx + 6] or 0), vel = vel}
  elseif chord_mode == 4 then
    notes[#notes+1] = {note = note, vel = vel}
    notes[#notes+1] = {note = note + 7, vel = vel}
    notes[#notes+1] = {note = note + 12, vel = vel}
  end

  for _, n in ipairs(notes) do
    n.note = math.max(0, math.min(127, n.note))
  end
  return notes
end

local function do_print()
  local heartbeat = reaper.gmem_read(700000)
  if heartbeat == 0 then
    reaper.ShowMessageBox("DroneMIDI2 not detected.\nMake sure it's loaded on a track.", "LMS Print MIDI", 0)
    return
  end

  local steps      = math.max(1, math.floor(reaper.gmem_read(700001)))
  local chan        = math.floor(reaper.gmem_read(700002))
  local root        = math.floor(reaper.gmem_read(700003))
  local scale_id    = math.floor(reaper.gmem_read(700004))
  local chord_mode  = math.floor(reaper.gmem_read(700005))
  local oct_idx     = math.floor(reaper.gmem_read(700006))
  local oct_offset  = oct_idx - 2

  if chord_mode == 0 then
    reaper.ShowMessageBox("Chord Mode is OFF — no notes to print.\nSet it to Single, Triad, 7th, or Power.", "LMS Print MIDI", 0)
    return
  end

  -- Read pattern
  local pattern = {}
  for s = 0, 15 do
    pattern[s] = {}
    for p = 0, 15 do
      pattern[s][p] = math.floor(reaper.gmem_read(700010 + s * 16 + p))
    end
  end

  -- Cursor position
  local cursor_pos = reaper.GetCursorPosition()
  local cursor_qn  = reaper.TimeMap2_timeToQN(0, cursor_pos)
  local step_len_qn = 0.25  -- 16th note
  local total_qn = steps * step_len_qn
  local end_pos = reaper.TimeMap2_QNToTime(0, cursor_qn + total_qn)

  -- Track
  local track = reaper.GetSelectedTrack(0, 0) or reaper.GetTrack(0, 0)
  if not track then
    reaper.ShowMessageBox("No track found. Select a track first.", "LMS Print MIDI", 0)
    return
  end

  -- Create MIDI item
  reaper.Undo_BeginBlock()
  local item = reaper.CreateNewMIDIItemInProj(track, cursor_pos, end_pos)
  local take = reaper.GetActiveTake(item)
  if not take then
    reaper.Undo_EndBlock("LMS Print MIDI (failed)", -1)
    return
  end

  -- Delete default note
  local _, num_notes = reaper.MIDI_CountEvts(take)
  for i = num_notes - 1, 0, -1 do
    reaper.MIDI_DeleteNote(take, i)
  end

  -- Insert pattern notes
  local note_count = 0
  for s = 0, steps - 1 do
    for p = 0, 15 do
      local vel = pattern[s][p]
      if vel > 0 then
        local notes = build_notes(p, vel, root, scale_id, chord_mode, oct_offset)
        local start_ppq = reaper.MIDI_GetPPQPosFromProjQN(take, cursor_qn + s * step_len_qn)
        local end_ppq   = reaper.MIDI_GetPPQPosFromProjQN(take, cursor_qn + (s + 1) * step_len_qn)
        for _, n in ipairs(notes) do
          reaper.MIDI_InsertNote(take, false, false, start_ppq, end_ppq, chan, n.note, n.vel, true)
          note_count = note_count + 1
        end
      end
    end
  end

  reaper.MIDI_Sort(take)
  reaper.UpdateItemInProject(item)
  reaper.Undo_EndBlock("LMS: Print DroneMIDI2 (" .. note_count .. " notes)", -1)
  reaper.UpdateArrange()
end

-- Background mode: poll for PRINT button flag
local function poll()
  local flag = reaper.gmem_read(700500)
  if flag == 1 then
    reaper.gmem_write(700500, 0)  -- clear flag
    do_print()
  end
  reaper.defer(poll)
end

-- If gmem flag is already set (one-shot run), print immediately.
-- Otherwise enter background polling loop.
local flag = reaper.gmem_read(700500)
if flag == 1 then
  reaper.gmem_write(700500, 0)
  do_print()
else
  -- Check if DroneMIDI2 is live — if so, enter background mode
  local hb = reaper.gmem_read(700000)
  if hb > 0 then
    poll()
  else
    -- One-shot: just try to print now
    do_print()
  end
end
