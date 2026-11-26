-- Dictionary-lookup popup user patch: one row of four icon buttons.
--
--     close | highlight | search | close
--
-- ui/widget/dictquicklookup.lua builds that popup in buildButtonLayout(): it maps
-- layout ids (ReaderDictionary.default_layout, or the dict_button_config setting)
-- onto entries from _getButtonPool(). For the plain dictionary popup this patch
-- skips both and returns the fixed row; the wiki variants keep the upstream layout.
-- Consequences: the "customize buttons" setting no longer affects this popup, and
-- plugin/transient button rows (e.g. "follow link") no longer appear in it.
--
-- Icons: "close" is KOReader's own resources/icons/mdlight/close.svg; the other two
-- ship in patches/icons/ and are deployed to <koreader>/icons.

local DictQuickLookup = require("ui/widget/dictquicklookup")
local logger = require("logger")

local ICON_CLOSE = "close"
local ICON_HIGHLIGHT = "hlmenu_highlight"
local ICON_SEARCH = "hlmenu_search"

-- Icon-only copy of a pool entry. Entries are specs, not widgets: the same table
-- may be used for two slots (the two Close buttons) without sharing a widget.
local function icon_entry(pool, id, icon)
    local entry = pool[id]
    if not entry then return nil end
    local copy = {}
    for key, value in pairs(entry) do copy[key] = value end
    copy.icon = icon
    copy.text = nil
    return copy
end

local orig_buildButtonLayout = DictQuickLookup.buildButtonLayout

DictQuickLookup.buildButtonLayout = function(self)
    if self.is_wiki or self.is_wiki_fullpage then
        return orig_buildButtonLayout(self)
    end

    local pool = self:_getButtonPool()
    local close = icon_entry(pool, "close", ICON_CLOSE)
    local highlight = icon_entry(pool, "highlight", ICON_HIGHLIGHT)
    local search = icon_entry(pool, "search", ICON_SEARCH)
    if not (close and highlight and search) then
        logger.warn("dict button pool incomplete, keeping the stock layout")
        return orig_buildButtonLayout(self)
    end

    -- Upstream's highlight button only toggles save_highlight, and the highlight is
    -- saved when the popup closes. Save right away instead (like the selection popup)
    -- and grey the button out; the popup stays open. Upstream's own save path is used,
    -- so the looked-up word is highlighted without extending it to the sentence.
    -- shortuct: one save per looked-up word; saving the same word twice in a row is ignored.
    local already_saved = self._hlmenu_saved_word == self.lookupword
    if already_saved then highlight.enabled = false end
    highlight.callback = function()
        if self._hlmenu_saved_word == self.lookupword then return end
        if not self.highlight then return end
        self.highlight:saveHighlight()
        self._hlmenu_saved_word = self.lookupword
        local button = self.button_table and self.button_table:getButtonById("highlight")
        if button then button:disable() end
    end

    return { { close, highlight, search, icon_entry(pool, "close", ICON_CLOSE) } }
end
