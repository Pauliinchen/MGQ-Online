#----------------------------------------------------------------
#  world_overview_mods.rbx
#
#  Changelog:
#      Paulinchen  2026-11-01: Showed the pages of other mods in the Mod Framework's page views
#      Paulinchen  2026-10-31: Read the game's buttons past the capture through the Mod Framework
#      Paulinchen  2026-10-24: Created
#
#----------------------------------------------------------------

# Pages other mods offer the World overview, each shown as a tab of its own in a page view of the
# Mod Framework, which reads the page as its :mod_page: groups, row, and as it answers them head,
# pane, adjust, menu and choose (see "Page views" in the framework's MODDER.md). Beside those a page
# answers title (its tab's title) and shown? (whether it has anything to show now). The mods add
# their pages to ModPages, which neither side owns: whichever loads first defines it, so no mod
# names another.

# The pages mods offer to other mods' screens, kept apart from every mod.
module ModPages
  @pages = []

  # Adds a page once.
  #
  # @param page [Object] The page, answering what world_overview_mods.rbx lists.
  def self.add(page)
    @pages << page unless @pages.include?(page)
  end

  # Lists the pages added, in their order.
  #
  # @return [Array<Object>] The pages.
  def self.all
    @pages.dup
  end
end unless defined?(ModPages)

module MGQ_MpWorldOverview
  # What starts a mod page's key among the pages, followed by its place in ModPages.all.
  MOD_PAGE = "mod_"

  # Lists the tabs of the mod pages that have something to show, at most MOD_TABS; asked once a
  # frame, since the overview asks for its pages many times a frame.
  #
  # @return [Array<Array>] Each page's key and its tab's title.
  def self.mod_tabs
    return @mod_tabs if @mod_tabs && @mod_tabs_at == Graphics.frame_count

    tabs = []
    ModPages.all.each_with_index do |page, index|
      break if tabs.size >= MOD_TABS

      shown = begin
        page.shown?
      rescue => e
        log_once([:mod_shown, index], "a mod page failed to tell whether it shows: #{e.class}: #{e.message}")
        false
      end
      tabs << [:"#{MOD_PAGE}#{index}", page.title.to_s] if shown
    end
    @mod_tabs_at = Graphics.frame_count
    @mod_tabs = tabs
  end

  # Reports whether a page is a mod's.
  #
  # @param page [Symbol] The page.
  # @return [Boolean] Whether it is.
  def self.mod_page?(page)
    page.to_s.start_with?(MOD_PAGE)
  end

  # Finds the mod's page behind a page's key.
  #
  # @param page [Symbol] The page's key, see mod_tabs.
  # @return [Object, nil] The page; nil once the mod no longer offers it.
  def self.mod_page(page)
    ModPages.all[page.to_s[MOD_PAGE.size..-1].to_i]
  end

  # Makes the page view of a mod's page, which reads the page itself.
  #
  # @param page [Symbol] The page's key, see mod_tabs.
  # @param tab [Mod_Framework::UI::Stack] The page of its tab.
  # @return [Mod_Framework::UI::PageView] The view.
  def self.mod_view(page, tab)
    tab.add_page_view(:id => :"overview_#{page}", :mod_page => mod_page(page), :said => lambda { |text| mod_said(page, text) })
  end

  # Posts what a mod's page answered to a change or a choice as a notice, and logs it.
  #
  # @param page [Symbol] The page's key.
  # @param text [String] What it answered.
  def self.mod_said(page, text)
    log("the #{mod_page(page).title} page said: #{text}")
    MGQ_MpOverworldSync.notice(text)
  end
end
