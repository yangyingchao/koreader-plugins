-- Highlight-menu user patch: one row of six icon buttons for a fresh text selection.
--
-- Reuses KOReader's own popup builder (apps/reader/modules/readerhighlight.lua:
-- onShowHighlightMenu) and only edits its input table `_highlight_buttons`: the
-- unwanted entries are dropped, three icon buttons are added, the three kept ones
-- lose their text label, and the two-column grid is folded into a single row.
-- Nothing else in the popup is reimplemented.
--
-- Icons come from userpatches/icons/, which deploy_to_kindle.sh copies into
-- <koreader>/icons -- IconWidget's user icon dir (ui/widget/iconwidget.lua:21).

local ReaderHighlight = require("apps/reader/modules/readerhighlight")
local ButtonDialog = require("ui/widget/buttondialog")
local logger = require("logger")

-- Upstream entries kept as-is, keyed by their exact registry name, plus the icon
-- each one is shown with. Everything else is dropped: select, highlight, copy,
-- wikipedia, translate, hyphenate, follow link, view html, share text, and
-- whatever plugins added.
local KEEP_ICONS = {
    ["04_add_note"] = "hlmenu_note",
    ["06_dictionary"] = "hlmenu_dictionary",
    ["12_search"] = "hlmenu_search",
}

-- Drop the text label of an upstream button factory, keeping its enabled/callback.
-- A factory is wrapped only once per popup table; re-wrapped ones are reused.
local wrapped_icons = setmetatable({}, { __mode = "k" })

local function icon_only(fn_button, icon)
    if wrapped_icons[fn_button] == icon then return fn_button end
    local wrapped = function(this, index)
        local button = fn_button(this, index)
        button.icon = icon
        button.text = nil
        return button
    end
    wrapped_icons[wrapped] = icon
    return wrapped
end

local function highlight_now(this)
    this.view.highlight.saved_color =
        G_reader_settings:readSetting("highlight_color") or this._fallback_color
    if this.setSelectionColor then this:setSelectionColor() end
    this:saveHighlight(true) -- true: extend the selection to the sentence
    this:onClose()
end

local function underline_now(this)
    local highlight = this.view.highlight
    local drawer, color = highlight.saved_drawer, highlight.saved_color
    highlight.saved_drawer, highlight.saved_color = "underscore", "gray"
    local ok, err = pcall(function() this:saveHighlight(true) end)
    highlight.saved_drawer, highlight.saved_color = drawer, color
    this:onClose()
    if not ok then logger.err("underline save failed: " .. tostring(err)) end
end

local function highlight_button(this)
    return {
        icon = "hlmenu_highlight",
        -- Only a fresh selection can be saved; greyed out for an existing highlight.
        enabled = this.hold_pos ~= nil,
        callback = function() highlight_now(this) end,
    }
end

-- Keys are iterated alphabetically (base/ffi/util.lua orderedPairs), so the
-- prefixes set the button order: highlight | add_note | dictionary | search |
-- underline | highlight.
local EXTRA_BUTTONS = {
    ["01_hlmenu_highlight"] = highlight_button,
    ["98_hlmenu_underline"] = function(this)
        return {
            icon = "hlmenu_underline",
            enabled = this.hold_pos ~= nil,
            callback = function() underline_now(this) end,
        }
    end,
    ["99_hlmenu_highlight_right"] = highlight_button,
}

local orig_onShowHighlightMenu = ReaderHighlight.onShowHighlightMenu

ReaderHighlight.onShowHighlightMenu = function(self, index)
    local buttons = self._highlight_buttons
    if type(buttons) ~= "table" then return orig_onShowHighlightMenu(self, index) end

    for key, fn_button in pairs(buttons) do
        local icon = KEEP_ICONS[key]
        buttons[key] = icon and icon_only(fn_button, icon) or nil
    end
    -- _highlight_buttons is rebuilt by ReaderHighlight:init for every document,
    -- so the three added entries have to be re-added on each call.
    for key, fn_button in pairs(EXTRA_BUTTONS) do buttons[key] = fn_button end

    -- Upstream lays the buttons out two per row; fold the rows into one. Hooking
    -- the single ButtonDialog.new call of onShowHighlightMenu lets the dialog be
    -- built at its final size, instead of resizing it after it is shown.
    local orig_buttondialog_new = ButtonDialog.new
    ButtonDialog.new = function(class, spec, ...)
        ButtonDialog.new = orig_buttondialog_new
        if spec and spec.buttons and #spec.buttons > 1 then
            local row = {}
            for _i, buttons_row in ipairs(spec.buttons) do
                for _j, button in ipairs(buttons_row) do row[#row + 1] = button end
            end
            spec.buttons = { row }
        end
        return orig_buttondialog_new(class, spec, ...)
    end
    local ok, err = pcall(orig_onShowHighlightMenu, self, index)
    ButtonDialog.new = orig_buttondialog_new
    if not ok then error(err) end
end
