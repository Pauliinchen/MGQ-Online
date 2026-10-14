#----------------------------------------------------------------
#  damage_probe.rb
#
#  Changelog:
#      Paulinchen  2026-10-14: Created
#
#----------------------------------------------------------------

# Records each hit's damage factors, for the game (Ruby 1.9) and the server (Ruby 3.3) alike.
$damage_probe = []
class Game_Battler
  alias probe_make_damage_value make_damage_value

  # Notes the factors of a hit, then deals it.
  def make_damage_value(user, item, opt = {})
    begin
      f = lambda { |v| v.is_a?(Float) ? format("%.6f", v) : v.to_s }
      parts = []
      parts << "eval=#{f.call(item.eval_damage(user, self))}"
      parts << "elem=#{f.call(item_element_rate(user, item))}"
      parts << "pdr=#{f.call(pdr)}" if item.physical?
      parts << "mdr=#{f.call(mdr)}" if item.magical?
      parts << "boost=#{f.call(boost_rate(user, item, opt))}" unless item.invalid_boost?
      parts << "turnhit=#{f.call(turn_hit_damage_rate)}"
      parts << "crit=#{@result.critical}"
      if ENV["PROBE_DEEP"] || $probe_deep
        %w[booster_all_damage booster_ex_count].each { |m| parts << "#{m}=#{f.call(user.send(m))}" }
        %w[item_booster_element booster_weapon_equip_size booster_item_damage booster_states_damage booster_same_element_damage].each do |m|
          parts << "#{m}=#{f.call(user.send(m, item))}"
        end
        if item.is_skill?
          %w[boost_enemy_number_rate booster_pinchi booster_full_hp booster_full_mp booster_full_tp booster_single_skill_damage_boost booster_skill_type booster_skill booster_skill_timing].each do |m|
            parts << "#{m}=#{f.call(user.send(m, item))}"
          end
          parts << "booster_state_rate=#{f.call(user.booster_state_rate(self, item))}"
          parts << "one_rate=#{f.call(item.one_rate)}"
          parts << "booster_hit=#{f.call(user.booster_hit(item, opt[:hit_count]))}"
          parts << "ex_category=#{f.call(user.boost_ex_category_rate(self, item))}"
          parts << "equip_type=#{f.call(user.boost_equip_type_damage_rate(self))}"
          parts << "wtypes=#{user.wtypes.inspect} bonus=#{user.weapon_rate_bonus.inspect}"
          parts << "wtype_skill=#{(user.wtypes + user.weapon_rate_bonus).uniq.map { |w| f.call(user.booster_wtype_skill(w, item)) }.join("/")}"
          parts << "atk=#{user.atk} mat=#{user.mat} agi=#{user.agi} hp=#{user.hp}/#{user.mhp} states=#{user.states.map { |s| s.id }.join(",")}"
        end
      end
      $damage_probe << "#{user.name} -> #{name} item #{item.id}: #{parts.join(" ")}"
    rescue Exception => e
      $damage_probe << "#{user.name} -> #{name} item #{item.id}: probe failed #{e.class} #{e.message}"
    end
    probe_make_damage_value(user, item, opt)
  end
end
"probe installed"
