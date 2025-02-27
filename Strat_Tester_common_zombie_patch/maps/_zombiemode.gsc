#include maps\_anim; 
#include maps\_utility; 
#include common_scripts\utility;
#include maps\_music; 
#include maps\_zombiemode_utility; 
#include maps\_busing;

#using_animtree( "generic_human" ); 

main()
{
	level.player_too_many_weapons_monitor = false;
	level.player_too_many_weapons_monitor_func = ::player_too_many_weapons_monitor;
	level._dontInitNotifyMessage = 1;
	
	init_additionalprimaryweapon_machine_locations();

	// put things you'd like to be able to turn off in here above this line
	level thread maps\_zombiemode_ffotd::main_start();

	level.zombiemode = true;
	level.reviveFeature = false;
	level.contextualMeleeFeature = false;
	level.swimmingFeature = false;
	level.calc_closest_player_using_paths = true;
	level.zombie_melee_in_water = true;
	level.put_timed_out_zombies_back_in_queue = true;
	level.use_alternate_poi_positioning = true;
	
	//for tracking stats
	level.zombies_timeout_spawn = 0;
	level.zombies_timeout_playspace = 0;
	level.zombies_timeout_undamaged = 0;	
	level.zombie_player_killed_count = 0;
	level.zombie_trap_killed_count = 0;
	level.zombie_pathing_failed = 0;
	level.zombie_breadcrumb_failed = 0;
	level.box_hits = 0;
	level.trap_hits = 0;


	level.zombie_visionset = "zombie_neutral";

	if(GetDvar("anim_intro") == "1")
	{
		level.zombie_anim_intro = 1;
	}
	else
	{
		level.zombie_anim_intro = 0;
	}

	precache_shaders();
	precache_models();

	PrecacheItem( "frag_grenade_zm" );
	PrecacheItem( "claymore_zm" );

	//override difficulty
	level.skill_override = 1;
	maps\_gameskill::setSkill(undefined,level.skill_override);
	
	level.disable_player_damage_knockback = true;

	level._ZOMBIE_GIB_PIECE_INDEX_ALL = 0;
	level._ZOMBIE_GIB_PIECE_INDEX_RIGHT_ARM = 1;
	level._ZOMBIE_GIB_PIECE_INDEX_LEFT_ARM = 2;
	level._ZOMBIE_GIB_PIECE_INDEX_RIGHT_LEG = 3;
	level._ZOMBIE_GIB_PIECE_INDEX_LEFT_LEG = 4;
	level._ZOMBIE_GIB_PIECE_INDEX_HEAD = 5;
	level._ZOMBIE_GIB_PIECE_INDEX_GUTS = 6;

	init_dvars();
	init_mutators();
	init_strings();
	init_levelvars();
	init_animscripts();
	init_sounds();
	init_shellshocks();
	init_flags();
	init_client_flags();

	register_offhand_weapons_for_level_defaults();

	//Limit zombie to 24 max, must have for network purposes
	if ( !isdefined( level.zombie_ai_limit ) )
	{
		level.zombie_ai_limit = 24;
		SetAILimit( level.zombie_ai_limit );
	}

	init_fx(); 
	//maps\_zombiemode_ability::init();

	// load map defaults  
	maps\_zombiemode_load::main();

	// Initialize the zone manager above any scripts that make use of zone info
	maps\_zombiemode_zone_manager::init();

	// Call the other zombiemode scripts
	maps\_zombiemode_audio::audio_init();
	maps\_zombiemode_claymore::init();
	maps\_zombiemode_weapons::init();
	maps\_zombiemode_equipment::init();
	maps\_zombiemode_blockers::init();
	maps\_zombiemode_spawner::init();
	maps\_zombiemode_powerups::init();
	maps\_zombiemode_perks::init();
	maps\_zombiemode_user::init();
	maps\_zombiemode_weap_cymbal_monkey::init();
	maps\_zombiemode_weap_freezegun::init();
	maps\_zombiemode_weap_tesla::init();
	maps\_zombiemode_weap_thundergun::init();
	maps\_zombiemode_weap_crossbow::init();
//Z2	TEMP DISABLE DURING INTEGRATION
	maps\_zombiemode_bowie::bowie_init();
//	maps\_zombiemode_betty::init();
//	maps\_zombiemode_timer::init();
//	maps\_zombiemode_auto_turret::init();
	//maps\_zombiemode_protips::pro_tips_initialize();
	maps\_zombiemode_traps::init();
	maps\_zombiemode_weapon_box::init();
	/#
	maps\_zombiemode_devgui::init();
	#/

	init_function_overrides();
	
	// ww: init the pistols in the game so last stand has the importance order
	level thread last_stand_pistol_rank_init();

	//thread maps\_zombiemode_rank::init();

	// These MUST be threaded because they contain waits
	//level thread maps\_zombiemode_deathcard::init();
	//level thread maps\_zombiemode_money::init();
	level thread [[level.Player_Spawn_func]]();
	level thread onPlayerConnect(); 
	level thread post_all_players_connected();
	
	init_utility();
	maps\_utility::registerClientSys("zombify");	// register a client system...
	init_anims(); 	// zombie ai and anim inits

	if( isDefined( level.custom_ai_type ) )
	{
		for( i = 0; i < level.custom_ai_type.size; i++ )
		{
			[[ level.custom_ai_type[i] ]]();
		}
	}
	
	if( level.mutators[ "mutator_friendlyFire" ] )
	{
		SetDvar( "friendlyfire_enabled", "1" );
	}
	
	initZombieLeaderboardData();
	initializeStatTracking();	
	
	if ( GetPlayers().size <= 1 )
	{
		incrementCounter( "global_solo_games", 1 );
	}
	else if( level.systemLink )
	{
		incrementCounter( "global_systemlink_games", 1 );
	}
	else if ( GetDvarInt( #"splitscreen_playerCount" ) == GetPlayers().size )
	{
		incrementCounter( "global_splitscreen_games", 1 );
	}
	else // coop game
	{
		incrementCounter( "global_coop_games", 1 );
	}
	
	// Fog in splitscreen
	if( IsSplitScreen() )
	{
		set_splitscreen_fog( 350, 2986.33, 10000, -480, 0.805, 0.715, 0.61, 0.0, 10000 );
	}
	
	/#
	init_screen_stats();
	level thread update_screen_stats();
	#/

	level thread maps\_zombiemode_ffotd::main_end();
}

post_all_players_connected()
{
	flag_wait( "all_players_connected" ); 
/#
	execdevgui( "devgui_zombie" );
#/
	println( "sessions: mapname=", level.script, " gametype zom isserver 1 player_count=", get_players().size );

	
	maps\_zombiemode_score::init();
	level difficulty_init();

	//TTS
	//level thread hud_zombies_stats();
	// level thread hud_sph();

	//thread zombie_difficulty_ramp_up(); 

	// DCS 091610: clear up blood patches when set to mature.
	level thread clear_mature_blood();

	// Start the Zombie MODE!
	level thread end_game();
	
	if(!level.zombie_anim_intro)
	{
		level thread round_start();
	}
	level thread players_playing();
	if ( IsDefined( level.crawlers_enabled ) && level.crawlers_enabled == 1 )
	{
		level thread crawler_round_tracker();
	}

	//chrisp - adding spawning vo 
	//level thread spawn_vo();
	
	//add ammo tracker for VO
	level thread track_players_ammo_count();
	
	//level thread prevent_near_origin();

	DisableGrenadeSuicide();

	level.startInvulnerableTime = GetDvarInt( #"player_deathInvulnerableTime" );
// 	level.global_damage_func		= maps\_zombiemode_spawner::zombie_damage;
// 	level.global_damage_func_ads	= maps\_zombiemode_spawner::zombie_damage_ads;

	// TESTING
	//	wait( 3 );
	//	level thread intermission();
	//	thread testing_spawner_bug();

	if(!IsDefined(level.music_override) )
	{
		level.music_override = false;
	}
	
	//levelthreads
	level thread hud_game_time();
	level thread open_doors();
	level thread open_windows();
	level thread turn_on_power();
	level thread get_doors_nearby();
	level thread disable_powerup();
	level thread disable_special_zombies();

	if ( level.script == "zombie_pentagon" )
		level thread enable_traps_five();
	
	chests = getentarray( "treasure_chest_use", "targetname" );
	for ( i = 0; i < chests.size; i++ )
	{
		chests[i] thread checkforboxhit();
	}

	if (level.script == "zombie_cod5_factory" )
	{	
		level.wuen = 0;
		level.bridge = 0;
		level.ware = 0;

		wutrap = getentarray( "wuen_electric_trap", "targetname" );
		watrap = getentarray( "warehouse_electric_trap", "targetname" );
		brtrap = getentarray( "bridge_electric_trap", "targetname" );

		for ( i = 0; i < wutrap.size; i++ )
		{
			wutrap[i] thread checkfortraphit( 0 );
		}

		for ( i = 0; i < watrap.size; i++ )
		{
			watrap[i] thread checkfortraphit( 1 );
		}

		for ( i = 0; i < brtrap.size; i++ )
		{
			brtrap[i] thread checkfortraphit( 2 );
		}
	}
}

zombiemode_melee_miss()
{
	if( isDefined( self.enemy.curr_pay_turret ) )
	{
		self.enemy doDamage( GetDvarInt( #"ai_meleeDamage" ), self.origin, self, undefined, "melee", "none" );
	}
}

init_additionalprimaryweapon_machine_locations()
{
	mulekick_enabled = getDvar("mulekick_enabled");
	if( mulekick_enabled == "")
		mulekick_enabled = "1";
	if( mulekick_enabled == "0" ) { return; }

	switch ( Tolower( GetDvar( #"mapname" ) ) )
	{
	case "zombie_theater":
		level.zombie_additionalprimaryweapon_machine_origin = (1172.4, -359.7, 320);
		level.zombie_additionalprimaryweapon_machine_angles = (0, 90, 0);
		level.zombie_additionalprimaryweapon_machine_clip_origin = (1160, -360, 448);
		level.zombie_additionalprimaryweapon_machine_clip_angles = (0, 0, 0);
		break;
	case "zombie_pentagon":
		level.zombie_additionalprimaryweapon_machine_origin = (-1081.4, 1496.9, -512);
		level.zombie_additionalprimaryweapon_machine_angles = (0, 162.2, 0);
		level.zombie_additionalprimaryweapon_machine_clip_origin = (-1084, 1489, -448);
		level.zombie_additionalprimaryweapon_machine_clip_angles = (0, 341.4, 0);
		break;
	case "zombie_cosmodrome":
		level.zombie_additionalprimaryweapon_machine_origin = (420.8, 1359.1, 55);
		level.zombie_additionalprimaryweapon_machine_angles = (0, 270, 0);
		level.zombie_additionalprimaryweapon_machine_clip_origin = (436, 1359, 177);
		level.zombie_additionalprimaryweapon_machine_clip_angles = (0, 0, 0);

		level.zombie_additionalprimaryweapon_machine_monkey_angles = (0, 0, 0);
		level.zombie_additionalprimaryweapon_machine_monkey_origins = [];
		level.zombie_additionalprimaryweapon_machine_monkey_origins[0] = (398.8, 1398.6, 60);
		level.zombie_additionalprimaryweapon_machine_monkey_origins[1] = (380.8, 1358.6, 60);
		level.zombie_additionalprimaryweapon_machine_monkey_origins[2] = (398.8, 1318.6, 60);
		break;
	case "zombie_coast":
		level.zombie_additionalprimaryweapon_machine_origin = (2424.4, -2884.3, 314);
		level.zombie_additionalprimaryweapon_machine_angles = (0, 231.6, 0);
		level.zombie_additionalprimaryweapon_machine_clip_origin = (2435, -2893, 439);
		level.zombie_additionalprimaryweapon_machine_clip_angles = (0, 322.2, 0);
		break;
	case "zombie_temple":
		level.zombie_additionalprimaryweapon_machine_origin = (-1352.9, -1437.2, -485);
		level.zombie_additionalprimaryweapon_machine_angles = (0, 297.8, 0);
		level.zombie_additionalprimaryweapon_machine_clip_origin = (-1342, -1431, -361);
		level.zombie_additionalprimaryweapon_machine_clip_angles = (0, 28.8, 0);
		break;
	case "zombie_moon":
		level.zombie_additionalprimaryweapon_machine_origin = (1480.8, 3450, -65);
		level.zombie_additionalprimaryweapon_machine_angles = (0, 180, 0);
		break;
	case "zombie_cod5_prototype":
		level.zombie_additionalprimaryweapon_machine_origin = (-160, -528, 1);
		level.zombie_additionalprimaryweapon_machine_angles = (0, 0, 0);
		level.zombie_additionalprimaryweapon_machine_clip_origin = (-162, -517, 17);
		level.zombie_additionalprimaryweapon_machine_clip_angles = (0, 0, 0);
		break;
	case "zombie_cod5_asylum":
		level.zombie_additionalprimaryweapon_machine_origin = (-91, 540, 64);
		level.zombie_additionalprimaryweapon_machine_angles = (0, 90, 0);
		level.zombie_additionalprimaryweapon_machine_clip_origin = (-103, 540, 92);
		level.zombie_additionalprimaryweapon_machine_clip_angles = (0, 0, 0);
		break;
	case "zombie_cod5_sumpf":
		level.zombie_additionalprimaryweapon_machine_origin = (9565, 327, -529);
		level.zombie_additionalprimaryweapon_machine_angles = (0, 90, 0);
		level.zombie_additionalprimaryweapon_machine_clip_origin = (9555, 327, -402);
		level.zombie_additionalprimaryweapon_machine_clip_angles = (0, 0, 0);
		break;
	case "zombie_cod5_factory":
		level.zombie_additionalprimaryweapon_machine_origin = (-1089, -1366, 67);
		level.zombie_additionalprimaryweapon_machine_angles = (0, 90, 0);
		level.zombie_additionalprimaryweapon_machine_clip_origin = (-1100, -1365, 70);
		level.zombie_additionalprimaryweapon_machine_clip_angles = (0, 0, 0);
		break;
	}
}

/*------------------------------------
chrisp - adding vo to track players ammo
------------------------------------*/
track_players_ammo_count()
{
	self endon("disconnect");
	self endon("death");
	
	wait(5);
	
	while(1)
	{
		players = get_players();
		for(i=0;i<players.size;i++)
		{
	        if(!IsDefined (players[i].player_ammo_low))	
	        {
		        players[i].player_ammo_low = 0;
	        }	
	        if(!IsDefined(players[i].player_ammo_out))
	        {
		        players[i].player_ammo_out = 0;
	        }
			
			weap = players[i] getcurrentweapon();
			//iprintln("current weapon: " + weap);
			//iprintlnbold(weap);
			//Excludes all Perk based 'weapons' so that you don't get low ammo spam.
			if( !isDefined(weap) || 
					weap == "none" || 
					isSubStr( weap, "zombie_perk_bottle" ) || 
					is_placeable_mine( weap ) || 
					is_equipment( weap ) || 
					weap == "syrette_sp" || 
					weap == "zombie_knuckle_crack" || 
					weap == "zombie_bowie_flourish" || 
					weap == "zombie_sickle_flourish" || 
					issubstr( weap, "knife_ballistic_" ) || 
					( GetSubStr( weap, 0, 3) == "gl_" ) || 
					weap == "humangun_zm" || 
					weap == "humangun_upgraded_zm" ||
					weap == "equip_gasmask_zm" ||
					weap == "lower_equip_gasmask_zm" )
			{
				continue;
			}
			//iprintln("checking ammo for " + weap);
			if ( players[i] GetAmmoCount( weap ) > 5)
			{
				continue;
			}		
			if ( players[i] maps\_laststand::player_is_in_laststand() )
			{				
				continue;
			}
			else if (players[i] GetAmmoCount( weap ) < 5 && players[i] GetAmmoCount( weap ) > 0)
			{
				if (players[i].player_ammo_low != 1 )
				{
					players[i].player_ammo_low = 1;
					players[i] maps\_zombiemode_audio::create_and_play_dialog( "general", "ammo_low" );		
					players[i] thread ammo_dialog_timer();
				}
	
			}
			else if (players[i] GetAmmoCount( weap ) == 0)
			{	
				if(!isDefined(weap) || weap == "none")
				{
					continue;	
				}
				wait(2);
				
				if( !isdefined( players[i] ) )
				{
					return;
				}
				
				if( players[i] GetAmmoCount( weap ) != 0 )
				{
					continue;
				}
				
				if( players[i].player_ammo_out != 1 )	
				{		
				    players[i].player_ammo_out = 1;
				    players[i] maps\_zombiemode_audio::create_and_play_dialog( "general", "ammo_out" );	
				    players[i] thread ammoout_dialog_timer();		
				}										
			}
			else
			{
				continue;
			}
		}
		wait(.5);
	}	
}
ammo_dialog_timer()
{
	self endon("disconnect");
	self endon("death");

	wait(20);
	self.player_ammo_low = 0;			
}
ammoout_dialog_timer()
{
	self endon("disconnect");
	self endon("death");

    wait(20);
	self.player_ammo_out = 0;
}

/*------------------------------------
audio plays when more than 1 player connects
------------------------------------*/
spawn_vo()
{
	//not sure if we need this
	wait(1);
	
	players = getplayers();
	
	//just pick a random player for now and play some vo 
	if(players.size > 1)
	{
		player = random(players);
		index = maps\_zombiemode_weapons::get_player_index(player);
		player thread spawn_vo_player(index,players.size);
	}

}

spawn_vo_player(index,num)
{
	sound = "plr_" + index + "_vox_" + num +"play";
	self playsound(sound, "sound_done");			
	self waittill("sound_done");
}

testing_spawner_bug()
{
	wait( 0.1 );
	level.round_number = 7;

	spawners = [];
	spawners[0] = GetEnt( "testy", "targetname" );
	while( 1 )
	{
		wait( 1 );
		level.enemy_spawns = spawners;
	}
}

precache_shaders()
{
 	PrecacheShader( "hud_chalk_1" );
 	PrecacheShader( "hud_chalk_2" );
 	PrecacheShader( "hud_chalk_3" );
 	PrecacheShader( "hud_chalk_4" );
 	PrecacheShader( "hud_chalk_5" );

	PrecacheShader( "zom_icon_community_pot" );
	PrecacheShader( "zom_icon_community_pot_strip" );

	precacheshader("zom_icon_player_life");
}

precache_models()
{
	precachemodel( "char_ger_zombieeye" ); 
	precachemodel( "p_zom_win_bars_01_vert04_bend_180" ); 
	precachemodel( "p_zom_win_bars_01_vert01_bend_180" );
	precachemodel( "p_zom_win_bars_01_vert04_bend" ); 
	precachemodel( "p_zom_win_bars_01_vert01_bend" );
	PreCacheModel( "p_zom_win_cell_bars_01_vert04_bent" ); 
	precachemodel( "p_zom_win_cell_bars_01_vert01_bent" );
	PrecacheModel( "tag_origin" );

	// Counter models
	PrecacheModel( "p_zom_counter_0" );
	PrecacheModel( "p_zom_counter_1" );
	PrecacheModel( "p_zom_counter_2" );
	PrecacheModel( "p_zom_counter_3" );
	PrecacheModel( "p_zom_counter_4" );
	PrecacheModel( "p_zom_counter_5" );
	PrecacheModel( "p_zom_counter_6" );
	PrecacheModel( "p_zom_counter_7" );
	PrecacheModel( "p_zom_counter_8" );
	PrecacheModel( "p_zom_counter_9" );

	//	Player Tombstone
	precachemodel("zombie_revive");

	PrecacheModel( "zombie_z_money_icon" );
}

init_shellshocks()
{
	level.player_killed_shellshock = "zombie_death";
	PrecacheShellshock( level.player_killed_shellshock );
}

init_strings()
{
	PrecacheString( &"ZOMBIE_WEAPONCOSTAMMO" );
	PrecacheString( &"ZOMBIE_ROUND" );
	PrecacheString( &"SCRIPT_PLUS" );
	PrecacheString( &"ZOMBIE_GAME_OVER" );
	PrecacheString( &"ZOMBIE_SURVIVED_ROUND" );
	PrecacheString( &"ZOMBIE_SURVIVED_ROUNDS" );
	PrecacheString( &"ZOMBIE_SURVIVED_NOMANS" );
	PrecacheString( &"ZOMBIE_EXTRA_LIFE" );
 
	add_zombie_hint( "undefined", &"ZOMBIE_UNDEFINED" );

	// Random Treasure Chest
	add_zombie_hint( "default_treasure_chest_950", &"ZOMBIE_RANDOM_WEAPON_950" );

	// Barrier Pieces
	add_zombie_hint( "default_buy_barrier_piece_10", &"ZOMBIE_BUTTON_BUY_BACK_BARRIER_10" );
	add_zombie_hint( "default_buy_barrier_piece_20", &"ZOMBIE_BUTTON_BUY_BACK_BARRIER_20" );
	add_zombie_hint( "default_buy_barrier_piece_50", &"ZOMBIE_BUTTON_BUY_BACK_BARRIER_50" );
	add_zombie_hint( "default_buy_barrier_piece_100", &"ZOMBIE_BUTTON_BUY_BACK_BARRIER_100" );

	// REWARD Barrier Pieces
	add_zombie_hint( "default_reward_barrier_piece", &"ZOMBIE_BUTTON_REWARD_BARRIER" );
	add_zombie_hint( "default_reward_barrier_piece_10", &"ZOMBIE_BUTTON_REWARD_BARRIER_10" );
	add_zombie_hint( "default_reward_barrier_piece_20", &"ZOMBIE_BUTTON_REWARD_BARRIER_20" );
	add_zombie_hint( "default_reward_barrier_piece_30", &"ZOMBIE_BUTTON_REWARD_BARRIER_30" );
	add_zombie_hint( "default_reward_barrier_piece_40", &"ZOMBIE_BUTTON_REWARD_BARRIER_40" );
	add_zombie_hint( "default_reward_barrier_piece_50", &"ZOMBIE_BUTTON_REWARD_BARRIER_50" );

	// Debris
	add_zombie_hint( "default_buy_debris_100", &"ZOMBIE_BUTTON_BUY_CLEAR_DEBRIS_100" );
	add_zombie_hint( "default_buy_debris_200", &"ZOMBIE_BUTTON_BUY_CLEAR_DEBRIS_200" );
	add_zombie_hint( "default_buy_debris_250", &"ZOMBIE_BUTTON_BUY_CLEAR_DEBRIS_250" );
	add_zombie_hint( "default_buy_debris_500", &"ZOMBIE_BUTTON_BUY_CLEAR_DEBRIS_500" );
	add_zombie_hint( "default_buy_debris_750", &"ZOMBIE_BUTTON_BUY_CLEAR_DEBRIS_750" );
	add_zombie_hint( "default_buy_debris_1000", &"ZOMBIE_BUTTON_BUY_CLEAR_DEBRIS_1000" );
	add_zombie_hint( "default_buy_debris_1250", &"ZOMBIE_BUTTON_BUY_CLEAR_DEBRIS_1250" );
	add_zombie_hint( "default_buy_debris_1500", &"ZOMBIE_BUTTON_BUY_CLEAR_DEBRIS_1500" );
	add_zombie_hint( "default_buy_debris_1750", &"ZOMBIE_BUTTON_BUY_CLEAR_DEBRIS_1750" );
	add_zombie_hint( "default_buy_debris_2000", &"ZOMBIE_BUTTON_BUY_CLEAR_DEBRIS_2000" );

	// Doors
	add_zombie_hint( "default_buy_door_100", &"ZOMBIE_BUTTON_BUY_OPEN_DOOR_100" );
	add_zombie_hint( "default_buy_door_200", &"ZOMBIE_BUTTON_BUY_OPEN_DOOR_200" );
	add_zombie_hint( "default_buy_door_250", &"ZOMBIE_BUTTON_BUY_OPEN_DOOR_250" );
	add_zombie_hint( "default_buy_door_500", &"ZOMBIE_BUTTON_BUY_OPEN_DOOR_500" );
	add_zombie_hint( "default_buy_door_750", &"ZOMBIE_BUTTON_BUY_OPEN_DOOR_750" );
	add_zombie_hint( "default_buy_door_1000", &"ZOMBIE_BUTTON_BUY_OPEN_DOOR_1000" );
	add_zombie_hint( "default_buy_door_1250", &"ZOMBIE_BUTTON_BUY_OPEN_DOOR_1250" );
	add_zombie_hint( "default_buy_door_1500", &"ZOMBIE_BUTTON_BUY_OPEN_DOOR_1500" );
	add_zombie_hint( "default_buy_door_1750", &"ZOMBIE_BUTTON_BUY_OPEN_DOOR_1750" );
	add_zombie_hint( "default_buy_door_2000", &"ZOMBIE_BUTTON_BUY_OPEN_DOOR_2000" );

	// Areas
	add_zombie_hint( "default_buy_area_100", &"ZOMBIE_BUTTON_BUY_OPEN_AREA_100" );
	add_zombie_hint( "default_buy_area_200", &"ZOMBIE_BUTTON_BUY_OPEN_AREA_200" );
	add_zombie_hint( "default_buy_area_250", &"ZOMBIE_BUTTON_BUY_OPEN_AREA_250" );
	add_zombie_hint( "default_buy_area_500", &"ZOMBIE_BUTTON_BUY_OPEN_AREA_500" );
	add_zombie_hint( "default_buy_area_750", &"ZOMBIE_BUTTON_BUY_OPEN_AREA_750" );
	add_zombie_hint( "default_buy_area_1000", &"ZOMBIE_BUTTON_BUY_OPEN_AREA_1000" );
	add_zombie_hint( "default_buy_area_1250", &"ZOMBIE_BUTTON_BUY_OPEN_AREA_1250" );
	add_zombie_hint( "default_buy_area_1500", &"ZOMBIE_BUTTON_BUY_OPEN_AREA_1500" );
	add_zombie_hint( "default_buy_area_1750", &"ZOMBIE_BUTTON_BUY_OPEN_AREA_1750" );
	add_zombie_hint( "default_buy_area_2000", &"ZOMBIE_BUTTON_BUY_OPEN_AREA_2000" );

	// POWER UPS
	add_zombie_hint( "powerup_fire_sale_cost", &"ZOMBIE_FIRE_SALE_COST" );

	// ZONE NAMES
	switch(ToLower(GetDvar(#"mapname")))
	{
		case "zombie_theater":
			PrecacheString(&"REIMAGINED_ZOMBIE_THEATER_FOYER_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_THEATER_FOYER2_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_THEATER_CREMATORIUM_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_THEATER_ALLEYWAY_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_THEATER_WEST_BALCONY_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_THEATER_STAGE_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_THEATER_THEATER_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_THEATER_DRESSING_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_THEATER_DINING_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_THEATER_VIP_ZONE");
			break;
		case "zombie_pentagon":
			PrecacheString(&"REIMAGINED_ZOMBIE_PENTAGON_CONFERENCE_LEVEL1");
			PrecacheString(&"REIMAGINED_ZOMBIE_PENTAGON_HALLWAY_LEVEL1");
			PrecacheString(&"REIMAGINED_ZOMBIE_PENTAGON_WAR_ROOM_ZONE_TOP");
			PrecacheString(&"REIMAGINED_ZOMBIE_PENTAGON_WAR_ROOM_ZONE_NORTH");
			PrecacheString(&"REIMAGINED_ZOMBIE_PENTAGON_WAR_ROOM_ZONE_SOUTH");
			PrecacheString(&"REIMAGINED_ZOMBIE_PENTAGON_CONFERENCE_LEVEL2");
			PrecacheString(&"REIMAGINED_ZOMBIE_PENTAGON_WAR_ROOM_ZONE_ELEVATOR");
			PrecacheString(&"REIMAGINED_ZOMBIE_PENTAGON_LABS_ELEVATOR");
			PrecacheString(&"REIMAGINED_ZOMBIE_PENTAGON_LABS_HALLWAY1");
			PrecacheString(&"REIMAGINED_ZOMBIE_PENTAGON_LABS_HALLWAY2");
			PrecacheString(&"REIMAGINED_ZOMBIE_PENTAGON_LABS_ZONE3");
			PrecacheString(&"REIMAGINED_ZOMBIE_PENTAGON_LABS_ZONE2");
			PrecacheString(&"REIMAGINED_ZOMBIE_PENTAGON_LABS_ZONE1");
			break;
		case "zombie_cosmodrome":
			PrecacheString(&"REIMAGINED_ZOMBIE_COSMODROME_CENTRIFUGE_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_COSMODROME_CENTRIFUGE_ZONE2");
			PrecacheString(&"REIMAGINED_ZOMBIE_COSMODROME_ACCESS_TUNNEL_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_COSMODROME_STORAGE_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_COSMODROME_STORAGE_ZONE2");
			PrecacheString(&"REIMAGINED_ZOMBIE_COSMODROME_STORAGE_LANDER_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_COSMODROME_BASE_ENTRY_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_COSMODROME_CENTRIFUGE2POWER_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_COSMODROME_BASE_ENTRY_ZONE2");
			PrecacheString(&"REIMAGINED_ZOMBIE_COSMODROME_POWER_BUILDING");
			PrecacheString(&"REIMAGINED_ZOMBIE_COSMODROME_POWER_BUILDING_ROOF");
			PrecacheString(&"REIMAGINED_ZOMBIE_COSMODROME_ROOF_CONNECTOR_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_COSMODROME_NORTH_CATWALK_ZONE3");
			PrecacheString(&"REIMAGINED_ZOMBIE_COSMODROME_NORTH_PATH_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_COSMODROME_UNDER_ROCKET_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_COSMODROME_CONTROL_ROOM_ZONE");
			break;
		case "zombie_coast":
			PrecacheString(&"REIMAGINED_ZOMBIE_COAST_BEACH_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_COAST_START_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_COAST_SHIPBACK_FAR_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_COAST_NEAR_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_COAST_SHIPBACK_NEAR_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_COAST_SHIPBACK_NEAR2_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_COAST_SHIPBACK_LEVEL3_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_COAST_SHIPFRONT_NEAR_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_COAST_SHIPFRONT_BOTTOM_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_COAST_SHIPFRONT_FAR_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_COAST_SHIPFRONT_STORAGE_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_COAST_SHIPFRONT_2_BEACH_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_COAST_BEACH_ZONE2");
			PrecacheString(&"REIMAGINED_ZOMBIE_COAST_RESIDENCE_ROOF_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_COAST_RESIDENCE1_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_COAST_LIGHTHOUSE1_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_COAST_LIGHTHOUSE2_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_COAST_CATWALK_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_COAST_START_CAVE_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_COAST_START_BEACH_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_COAST_REAR_LAGOON_ZONE");
			break;
		case "zombie_temple":
			PrecacheString(&"REIMAGINED_ZOMBIE_TEMPLE_TEMPLE_START_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_TEMPLE_PRESSURE_PLATE_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_TEMPLE_CAVE_TUNNEL_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_TEMPLE_CAVES1_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_TEMPLE_CAVES2_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_TEMPLE_CAVES3_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_TEMPLE_POWER_ROOM_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_TEMPLE_CAVES_WATER_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_TEMPLE_WATERFALL_LOWER_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_TEMPLE_WATERFALL_TUNNEL_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_TEMPLE_WATERFALL_TUNNEL_A_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_TEMPLE_WATERFALL_UPPER_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_TEMPLE_WATERFALL_UPPER1_ZONE");
			break;
		case "zombie_moon":
			PrecacheString(&"REIMAGINED_ZOMBIE_MOON_NML_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_MOON_BRIDGE_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_MOON_WATER_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_MOON_CATA_LEFT_START_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_MOON_CATA_LEFT_MIDDLE_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_MOON_GENERATOR_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_MOON_CATA_RIGHT_START_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_MOON_CATA_RIGHT_MIDDLE_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_MOON_CATA_RIGHT_END_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_MOON_GENERATOR_EXIT_EAST_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_MOON_ENTER_FOREST_EAST_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_MOON_TOWER_ZONE_EAST");
			PrecacheString(&"REIMAGINED_ZOMBIE_MOON_TOWER_ZONE_EAST2");
			PrecacheString(&"REIMAGINED_ZOMBIE_MOON_FOREST_ZONE");
			break;
		case "zombie_cod5_prototype":
			PrecacheString(&"REIMAGINED_ZOMBIE_COD5_PROTOTYPE_START_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_COD5_PROTOTYPE_BOX_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_COD5_PROTOTYPE_UPSTAIRS_ZONE");
			break;
		case "zombie_cod5_asylum":
			PrecacheString(&"REIMAGINED_ZOMBIE_COD5_ASYLUM_WEST_DOWNSTAIRS_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_COD5_ASYLUM_WEST2_DOWNSTAIRS_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_COD5_ASYLUM_NORTH_DOWNSTAIRS_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_COD5_ASYLUM_SOUTH_UPSTAIRS_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_COD5_ASYLUM_SOUTH2_UPSTAIRS_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_COD5_ASYLUM_POWER_UPSTAIRS_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_COD5_ASYLUM_KITCHEN_UPSTAIRS_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_COD5_ASYLUM_NORTH_UPSTAIRS_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_COD5_ASYLUM_NORTH2_UPSTAIRS_ZONE");
			break;
		case "zombie_cod5_sumpf":
			PrecacheString(&"REIMAGINED_ZOMBIE_COD5_SUMPF_CENTER_BUILDING_UPSTAIRS");
			PrecacheString(&"REIMAGINED_ZOMBIE_COD5_SUMPF_CENTER_BUILDING_UPSTAIRS_BUY");
			PrecacheString(&"REIMAGINED_ZOMBIE_COD5_SUMPF_CENTER_BUILDING_COMBINED");
			PrecacheString(&"REIMAGINED_ZOMBIE_COD5_SUMPF_NORTHWEST_OUTSIDE");
			PrecacheString(&"REIMAGINED_ZOMBIE_COD5_SUMPF_NORTHWEST_BUILDING");
			PrecacheString(&"REIMAGINED_ZOMBIE_COD5_SUMPF_SOUTHWEST_OUTSIDE");
			PrecacheString(&"REIMAGINED_ZOMBIE_COD5_SUMPF_SOUTHWEST_BUILDING");
			PrecacheString(&"REIMAGINED_ZOMBIE_COD5_SUMPF_NORTHEAST_OUTSIDE");
			PrecacheString(&"REIMAGINED_ZOMBIE_COD5_SUMPF_NORTHEAST_BUILDING");
			PrecacheString(&"REIMAGINED_ZOMBIE_COD5_SUMPF_SOUTHEAST_OUTSIDE");
			PrecacheString(&"REIMAGINED_ZOMBIE_COD5_SUMPF_SOUTHEAST_BUILDING");
			break;
		case "zombie_cod5_factory":
			PrecacheString(&"REIMAGINED_ZOMBIE_COD5_FACTORY_RECEIVER_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_COD5_FACTORY_OUTSIDE_WEST_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_COD5_FACTORY_OUTSIDE_EAST_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_COD5_FACTORY_OUTSIDE_SOUTH_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_COD5_FACTORY_WNUEN_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_COD5_FACTORY_WNUEN_BRIDGE_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_COD5_FACTORY_BRIDGE_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_COD5_FACTORY_TP_EAST_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_COD5_FACTORY_TP_WEST_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_COD5_FACTORY_TP_SOUTH_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_COD5_FACTORY_WAREHOUSE_TOP_ZONE");
			PrecacheString(&"REIMAGINED_ZOMBIE_COD5_FACTORY_WAREHOUSE_BOTTOM_ZONE");
			break;

		default:
			// Precache custom map's zone names, if any
			if(isdefined(level._zombiemode_precache_zone_strings))
				level [[level._zombiemode_precache_zone_strings]]();
			break;
	}

}

init_sounds()
{
	add_sound( "end_of_round", "mus_zmb_round_over" );
	add_sound( "end_of_game", "mus_zmb_game_over" ); //Had to remove this and add a music state switch so that we can add other musical elements.
	add_sound( "chalk_one_up", "mus_zmb_chalk" );
	add_sound( "purchase", "zmb_cha_ching" );
	add_sound( "no_purchase", "zmb_no_cha_ching" );

	// Zombification
	// TODO need to vary these up
	add_sound( "playerzombie_usebutton_sound", "zmb_zombie_vocals_attack" );
	add_sound( "playerzombie_attackbutton_sound", "zmb_zombie_vocals_attack" );
	add_sound( "playerzombie_adsbutton_sound", "zmb_zombie_vocals_attack" );

	// Head gib
	add_sound( "zombie_head_gib", "zmb_zombie_head_gib" );

	// Blockers
	add_sound( "rebuild_barrier_piece", "zmb_repair_boards" );
	add_sound( "rebuild_barrier_metal_piece", "zmb_metal_repair" );
	add_sound( "rebuild_barrier_hover", "zmb_boards_float" );
	add_sound( "debris_hover_loop", "zmb_couch_loop" );
	add_sound( "break_barrier_piece", "zmb_break_boards" );
	add_sound( "grab_metal_bar", "zmb_bar_pull" );
	add_sound( "break_metal_bar", "zmb_bar_break" );
	add_sound( "drop_metal_bar", "zmb_bar_drop" );
	add_sound("blocker_end_move", "zmb_board_slam");
	add_sound( "barrier_rebuild_slam", "zmb_board_slam" );
	add_sound( "bar_rebuild_slam", "zmb_bar_repair" );
	add_sound( "zmb_rock_fix", "zmb_break_rock_barrier_fix" );
	add_sound( "zmb_vent_fix", "evt_vent_slat_repair" );

	// Doors
	add_sound( "door_slide_open", "zmb_door_slide_open" );
	add_sound( "door_rotate_open", "zmb_door_slide_open" );

	// Debris
	add_sound( "debris_move", "zmb_weap_wall" );

	// Random Weapon Chest
	add_sound( "open_chest", "zmb_lid_open" );
	add_sound( "music_chest", "zmb_music_box" );
	add_sound( "close_chest", "zmb_lid_close" );

	// Weapons on walls
	add_sound( "weapon_show", "zmb_weap_wall" );

}

init_levelvars()
{
	// Variables
	// used to a check in last stand for players to become zombies
	level.is_zombie_level			= true; 
	level.laststandpistol			= "m1911_zm";		// so we dont get the uber colt when we're knocked out
	level.first_round				= false;
	level.round_number				= 1;
	level.round_start_time			= 0;
	level.pro_tips_start_time		= 0;
	level.intermission				= false;
	level.dog_intermission			= false;
	level.zombie_total				= 0;
	level.total_zombies_killed		= 0;
	level.no_laststandmissionfail	= true;
	level.hudelem_count				= 0;
	level.zombie_move_speed			= 1; 
	level.enemy_spawns				= [];				// List of normal zombie spawners
	level.zombie_rise_spawners		= [];				// List of zombie riser locations
//	level.crawlers_enabled			= 1;

	// Used for kill counters
	level.counter_model[0] = "p_zom_counter_0";
	level.counter_model[1] = "p_zom_counter_1";
	level.counter_model[2] = "p_zom_counter_2";
	level.counter_model[3] = "p_zom_counter_3";
	level.counter_model[4] = "p_zom_counter_4";
	level.counter_model[5] = "p_zom_counter_5";
	level.counter_model[6] = "p_zom_counter_6";
	level.counter_model[7] = "p_zom_counter_7";
	level.counter_model[8] = "p_zom_counter_8";
	level.counter_model[9] = "p_zom_counter_9";

	level.zombie_vars = [];

	difficulty = 1;
	column = int(difficulty) + 1;

	//#######################################################################
	// NOTE:  These values are in mp/zombiemode.csv and will override 
	//	whatever you put in as a value below.  However, if they don't exist
	//	in the file, then the values below will be used.
	//#######################################################################
	//	set_zombie_var( identifier, 					value,	float,	column );

	// AI
	set_zombie_var( "zombie_health_increase", 			100,	false,	column );	//	cumulatively add this to the zombies' starting health each round (up to round 10)
	set_zombie_var( "zombie_health_increase_multiplier",0.1, 	true,	column );	//	after round 10 multiply the zombies' starting health by this amount
	set_zombie_var( "zombie_health_start", 				150,	false,	column );	//	starting health of a zombie at round 1
	set_zombie_var( "zombie_spawn_delay", 				2.0,	true,	column );	// Base time to wait between spawning zombies.  This is modified based on the round number.
	set_zombie_var( "zombie_new_runner_interval", 		 10,	false,	column );	//	Interval between changing walkers who are too far away into runners 
	set_zombie_var( "zombie_move_speed_multiplier", 	  8,	false,	column );	//	Multiply by the round number to give the base speed value.  0-40 = walk, 41-70 = run, 71+ = sprint

	set_zombie_var( "zombie_max_ai", 					24,		false,	column );	//	Base number of zombies per player (modified by round #)
	set_zombie_var( "zombie_ai_per_player", 			6,		false,	column );	//	additional zombie modifier for each player in the game
	set_zombie_var( "below_world_check", 				-1000 );					//	Check height to see if a zombie has fallen through the world.

	// Round	
	set_zombie_var( "spectators_respawn", 				true );		// Respawn in the spectators in between rounds
	set_zombie_var( "zombie_use_failsafe", 				true );		// Will slowly kill zombies who are stuck
	set_zombie_var( "zombie_between_round_time", 		10 );		// How long to pause after the round ends
	set_zombie_var( "zombie_intermission_time", 		15 );		// Length of time to show the end of game stats
	set_zombie_var( "game_start_delay", 				0,		false,	column );	// How much time to give people a break before starting spawning

	// Life and death
	set_zombie_var( "penalty_no_revive", 				0.10, 	true,	column );	// Percentage of money you lose if you let a teammate die
	set_zombie_var( "penalty_died",						0.0, 	true,	column );	// Percentage of money lost if you die
	set_zombie_var( "penalty_downed", 					0.05, 	true,	column );	// Percentage of money lost if you go down // ww: told to remove downed point loss
	set_zombie_var( "starting_lives", 					1, 		false,	column );	// How many lives a solo player starts out with

	players = get_players();
	points = set_zombie_var( ("zombie_score_start_"+players.size+"p"), 3000, false, column );
	points = set_zombie_var( ("zombie_score_start_"+players.size+"p"), 3000, false, column );


	set_zombie_var( "zombie_score_kill_4player", 		50 );		// Individual Points for a zombie kill in a 4 player game
	set_zombie_var( "zombie_score_kill_3player",		50 );		// Individual Points for a zombie kill in a 3 player game
	set_zombie_var( "zombie_score_kill_2player",		50 );		// Individual Points for a zombie kill in a 2 player game
	set_zombie_var( "zombie_score_kill_1player",		50 );		// Individual Points for a zombie kill in a 1 player game

	set_zombie_var( "zombie_score_kill_4p_team", 		30 );		// Team Points for a zombie kill in a 4 player game
	set_zombie_var( "zombie_score_kill_3p_team",		35 );		// Team Points for a zombie kill in a 3 player game
	set_zombie_var( "zombie_score_kill_2p_team",		45 );		// Team Points for a zombie kill in a 2 player game
	set_zombie_var( "zombie_score_kill_1p_team",		 0 );		// Team Points for a zombie kill in a 1 player game

	set_zombie_var( "zombie_score_damage_normal",		10 );		// points gained for a hit with a non-automatic weapon
	set_zombie_var( "zombie_score_damage_light",		10 );		// points gained for a hit with an automatic weapon

	set_zombie_var( "zombie_score_bonus_melee", 		80 );		// Bonus points for a melee kill
	set_zombie_var( "zombie_score_bonus_head", 			50 );		// Bonus points for a head shot kill
	set_zombie_var( "zombie_score_bonus_neck", 			20 );		// Bonus points for a neck shot kill
	set_zombie_var( "zombie_score_bonus_torso", 		10 );		// Bonus points for a torso shot kill
	set_zombie_var( "zombie_score_bonus_burn", 			10 );		// Bonus points for a burn kill

	set_zombie_var( "zombie_flame_dmg_point_delay",		500 );	

	set_zombie_var( "zombify_player", 					false );	// Default to not zombify the player till further support

	if ( IsSplitScreen() )
	{
		set_zombie_var( "zombie_timer_offset", 			280 );	// hud offsets
	}
}

init_dvars()
{
	setSavedDvar( "fire_world_damage", "0" );	
	setSavedDvar( "fire_world_damage_rate", "0" );	
	setSavedDvar( "fire_world_damage_duration", "0" );	

	if( GetDvar( #"zombie_debug" ) == "" )
	{
		SetDvar( "zombie_debug", "0" );
	}

	if( GetDvar( #"zombie_cheat" ) == "" )
	{
		SetDvar( "zombie_cheat", "0" );
	}
	
	if ( level.script != "zombie_cod5_prototype" )
	{
		SetDvar( "magic_chest_movable", "1" );
	}

	if(GetDvar( #"magic_box_explore_only") == "")
	{
		SetDvar( "magic_box_explore_only", "1" );
	}

	SetDvar( "revive_trigger_radius", "75" ); 
	SetDvar( "player_lastStandBleedoutTime", "45" );

	SetDvar( "scr_deleteexplosivesonspawn", "0" );

	// HACK: To avoid IK crash in zombiemode: MikeA 9/18/2009	
	//setDvar( "ik_enable", "0" );
}


init_mutators()
{
	level.mutators = [];

	init_mutator( "mutator_noPerks" );
	init_mutator( "mutator_noTraps" );
	init_mutator( "mutator_noMagicBox" );
	init_mutator( "mutator_noRevive" );
	init_mutator( "mutator_noPowerups" );
	init_mutator( "mutator_noReloads" );
	init_mutator( "mutator_noBoards" );
	init_mutator( "mutator_fogMatch" );
	init_mutator( "mutator_quickStart" );
	init_mutator( "mutator_headshotsOnly" );
	init_mutator( "mutator_friendlyFire" );
	init_mutator( "mutator_doubleMoney" );
	init_mutator( "mutator_susceptible" );
	init_mutator( "mutator_powerShot" );
}

init_mutator( mutator_s )
{
	level.mutators[ mutator_s ] = ( "1" == GetDvar( mutator_s ) );
}


init_function_overrides()
{
	// Function pointers
	level.custom_introscreen		= ::zombie_intro_screen; 
	level.custom_intermission		= ::player_intermission; 
	level.reset_clientdvars			= ::onPlayerConnect_clientDvars;
	// Sets up function pointers for animscripts to refer to
	level.playerlaststand_func		= ::player_laststand;
	//	level.global_kill_func		= maps\_zombiemode_spawner::zombie_death; 
	level.global_damage_func		= maps\_zombiemode_spawner::zombie_damage; 
	level.global_damage_func_ads	= maps\_zombiemode_spawner::zombie_damage_ads;
	level.overridePlayerKilled		= ::player_killed_override;
	level.overridePlayerDamage		= ::player_damage_override; //_cheat;
	level.overrideActorKilled		= ::actor_killed_override;
	level.overrideActorDamage		= ::actor_damage_override;
	level.melee_miss_func			= ::zombiemode_melee_miss;
	level.player_becomes_zombie		= ::zombify_player; 
	level.is_friendly_fire_on		= ::is_friendly_fire_on; 
	level.can_revive				= ::can_revive;
	level.zombie_last_stand 		= ::last_stand_pistol_swap;
	level.zombie_last_stand_pistol_memory = ::last_stand_save_pistol_ammo;
	level.zombie_last_stand_ammo_return		= ::last_stand_restore_pistol_ammo;
	level.prevent_player_damage		= ::player_prevent_damage;

	if( !IsDefined( level.Player_Spawn_func ) )
	{
		level.Player_Spawn_func = ::coop_player_spawn_placement;
	}
}


// for zombietron, see maps\_zombietron_main::initZombieLeaderboardData()
//
initZombieLeaderboardData()
{
	// Initializing Leaderboard Stat Variables -- string values match stats.ddl
	level.zombieLeaderboardStatVariable["zombie_theater"]["highestwave"] = "zombie_theater_highestwave";
	level.zombieLeaderboardStatVariable["zombie_theater"]["timeinwave"]  = "zombie_theater_timeinwave";
	level.zombieLeaderboardStatVariable["zombie_theater"]["totalpoints"] = "zombie_theater_totalpoints";

	level.zombieLeaderboardStatVariable["zombie_pentagon"]["highestwave"] = "zombie_pentagon_highestwave";
	level.zombieLeaderboardStatVariable["zombie_pentagon"]["timeinwave"]  = "zombie_pentagon_timeinwave";
	level.zombieLeaderboardStatVariable["zombie_pentagon"]["totalpoints"] = "zombie_pentagon_totalpoints";

	// DLC 1 Cod 5 Zombies Leaderboard Stats

	level.zombieLeaderboardStatVariable["zombie_cod5_asylum"]["highestwave"] = "zombie_asylum_highestwave";
	level.zombieLeaderboardStatVariable["zombie_cod5_asylum"]["timeinwave"]  = "zombie_asylum_timeinwave";
	level.zombieLeaderboardStatVariable["zombie_cod5_asylum"]["totalpoints"] = "zombie_asylum_totalpoints";

	level.zombieLeaderboardStatVariable["zombie_cod5_factory"]["highestwave"] = "zombie_factory_highestwave";
	level.zombieLeaderboardStatVariable["zombie_cod5_factory"]["timeinwave"]  = "zombie_factory_timeinwave";
	level.zombieLeaderboardStatVariable["zombie_cod5_factory"]["totalpoints"] = "zombie_factory_totalpoints";

	level.zombieLeaderboardStatVariable["zombie_cod5_prototype"]["highestwave"] = "zombie_prototype_highestwave";
	level.zombieLeaderboardStatVariable["zombie_cod5_prototype"]["timeinwave"]  = "zombie_prototype_timeinwave";
	level.zombieLeaderboardStatVariable["zombie_cod5_prototype"]["totalpoints"] = "zombie_prototype_totalpoints";

	level.zombieLeaderboardStatVariable["zombie_cod5_sumpf"]["highestwave"] = "zombie_sumpf_highestwave";
	level.zombieLeaderboardStatVariable["zombie_cod5_sumpf"]["timeinwave"]  = "zombie_sumpf_timeinwave";
	level.zombieLeaderboardStatVariable["zombie_cod5_sumpf"]["totalpoints"] = "zombie_sumpf_totalpoints";
	
	// DLC 2 Zombies Leaderboard Stats
	
	level.zombieLeaderboardStatVariable["zombie_cosmodrome"]["highestwave"] = "zombie_cosmodrome_highestwave";
	level.zombieLeaderboardStatVariable["zombie_cosmodrome"]["timeinwave"]  = "zombie_cosmodrome_timeinwave";
	level.zombieLeaderboardStatVariable["zombie_cosmodrome"]["totalpoints"] = "zombie_cosmodrome_totalpoints";

	// DLC 3 Zombies Leaderboard Stats
	
	level.zombieLeaderboardStatVariable["zombie_coast"]["highestwave"] = "zombie_coast_highestwave";
	level.zombieLeaderboardStatVariable["zombie_coast"]["timeinwave"]  = "zombie_coast_timeinwave";
	level.zombieLeaderboardStatVariable["zombie_coast"]["totalpoints"] = "zombie_coast_totalpoints";

	// DLC 4 Zombies Leaderboard Stats
	
	level.zombieLeaderboardStatVariable["zombie_temple"]["highestwave"] = "zombie_temple_highestwave";
	level.zombieLeaderboardStatVariable["zombie_temple"]["timeinwave"]  = "zombie_temple_timeinwave";
	level.zombieLeaderboardStatVariable["zombie_temple"]["totalpoints"] = "zombie_temple_totalpoints";

	// DLC 5 Zombies Leaderboard Stats
	
	level.zombieLeaderboardStatVariable["zombie_moon"]["highestwave"] = "zombie_moon_highestwave";
	level.zombieLeaderboardStatVariable["zombie_moon"]["timeinwave"]  = "zombie_moon_timeinwave";
	level.zombieLeaderboardStatVariable["zombie_moon"]["totalpoints"] = "zombie_moon_totalpoints";
	level.zombieLeaderboardStatVariable["zombie_moon"]["nomanslandtime"] = "zombie_moon_nomansland";


	// Initializing Leaderboard Number.  Matches values in live_leaderboard.h.
	level.zombieLeaderboardNumber["zombie_theater"]["waves"] = 0;
	level.zombieLeaderboardNumber["zombie_theater"]["points"] = 1;

	// level.zombieLeaderboardNumber["zombietron"]["waves"] = 3;  // defined in _zombietron_main.gsc
	// level.zombieLeaderboardNumber["zombietron"]["points"] = 4; // defined in _zombietron_main.gsc

	level.zombieLeaderboardNumber["zombie_pentagon"]["waves"] = 6;
	level.zombieLeaderboardNumber["zombie_pentagon"]["points"] = 7;

	// DLC 1 Cod 5 Zombie leaderboards

	// Asylum
	level.zombieLeaderboardNumber["zombie_cod5_asylum"]["waves"] = 9;
	level.zombieLeaderboardNumber["zombie_cod5_asylum"]["points"] = 10;

	// Factory
	level.zombieLeaderboardNumber["zombie_cod5_factory"]["waves"] = 12;
	level.zombieLeaderboardNumber["zombie_cod5_factory"]["points"] = 13;

	// Prototype
	level.zombieLeaderboardNumber["zombie_cod5_prototype"]["waves"] = 15;
	level.zombieLeaderboardNumber["zombie_cod5_prototype"]["points"] = 16;

	// Sumpf
	level.zombieLeaderboardNumber["zombie_cod5_sumpf"]["waves"] = 18;
	level.zombieLeaderboardNumber["zombie_cod5_sumpf"]["points"] = 19;

	// DLC 2 Zombie leaderboards
	
	// Cosmodrome
	level.zombieLeaderboardNumber["zombie_cosmodrome"]["waves"] = 21;
	level.zombieLeaderboardNumber["zombie_cosmodrome"]["points"] = 22;

	// DLC 3 Zombie leaderboards
	
	// Coast
	level.zombieLeaderboardNumber["zombie_coast"]["waves"] = 24;
	level.zombieLeaderboardNumber["zombie_coast"]["points"] = 25;

	// DLC 4 Zombie leaderboards
	
	// Temple
	level.zombieLeaderboardNumber["zombie_temple"]["waves"] = 27;
	level.zombieLeaderboardNumber["zombie_temple"]["points"] = 28;
	
	// DLC 5 Zombie leaderboards
	
	// Moon
	level.zombieLeaderboardNumber["zombie_moon"]["waves"] = 30;
	level.zombieLeaderboardNumber["zombie_moon"]["points"] = 31;
	level.zombieLeaderboardNumber["zombie_moon"]["kills"] = 32;
}


init_flags()
{
	flag_init( "spawn_point_override" );
	flag_init( "power_on" );
	flag_init( "crawler_round" );
	flag_init( "spawn_zombies", true );
	flag_init( "dog_round" );
	flag_init( "begin_spawning" );
	flag_init( "end_round_wait" );
	flag_init( "wait_and_revive" );
	flag_init("instant_revive");	
}

// Client flags registered here should be for global zombie systems, and should
// prefer to use high flag numbers and work downwards.

// Level specific flags should be registered in the level, and should prefer 
// low numbers, and work upwards.

// Ensure that this function and the function in _zombiemode.csc match.

init_client_flags()
{
	// Client flags for script movers
	
	level._ZOMBIE_SCRIPTMOVER_FLAG_BOX_RANDOM	= 15;
	
	
	if(is_true(level.use_clientside_board_fx))
	{
		//for tearing down and repairing the boards and rock chunks
		level._ZOMBIE_SCRIPTMOVER_FLAG_BOARD_HORIZONTAL_FX	= 14;
		level._ZOMBIE_SCRIPTMOVER_FLAG_BOARD_VERTICAL_FX	= 13;
	}
	if(is_true(level.use_clientside_rock_tearin_fx))
	{
		level._ZOMBIE_SCRIPTMOVER_FLAG_ROCK_FX	= 12;	
	}
	
	// Client flags for the player
	
	level._ZOMBIE_PLAYER_FLAG_CLOAK_WEAPON = 14;
	level._ZOMBIE_PLAYER_FLAG_DIVE2NUKE_VISION = 13;
	level._ZOMBIE_PLAYER_FLAG_DEADSHOT_PERK = 12;

	if(is_true(level.riser_fx_on_client))
	{
		level._ZOMBIE_ACTOR_ZOMBIE_RISER_FX = 8;
		if(!isDefined(level._no_water_risers))
		{
			level._ZOMBIE_ACTOR_ZOMBIE_RISER_FX_WATER = 9;		
		}
		if(is_true(level.risers_use_low_gravity_fx))
		{
			level._ZOMBIE_ACTOR_ZOMBIE_RISER_LOWG_FX = 7;
		}
	}
	
}

init_fx()
{
	level._effect["wood_chunk_destory"]	 		= LoadFX( "impacts/fx_large_woodhit" );
	level._effect["fx_zombie_bar_break"]		= LoadFX( "maps/zombie/fx_zombie_bar_break" );
	level._effect["fx_zombie_bar_break_lite"]	= LoadFX( "maps/zombie/fx_zombie_bar_break_lite" );
	
	level._effect["edge_fog"]			 		= LoadFX( "maps/zombie/fx_fog_zombie_amb" ); 
	level._effect["chest_light"]		 		= LoadFX( "env/light/fx_ray_sun_sm_short" ); 

	level._effect["eye_glow"]			 		= LoadFX( "misc/fx_zombie_eye_single" ); 

	level._effect["headshot"] 					= LoadFX( "impacts/fx_flesh_hit" );
	level._effect["headshot_nochunks"] 			= LoadFX( "misc/fx_zombie_bloodsplat" );
	level._effect["bloodspurt"] 				= LoadFX( "misc/fx_zombie_bloodspurt" );
	level._effect["tesla_head_light"]			= LoadFX( "maps/zombie/fx_zombie_tesla_neck_spurt");

	level._effect["rise_burst_water"]			= LoadFX("maps/zombie/fx_zombie_body_wtr_burst");
	level._effect["rise_billow_water"]			= LoadFX("maps/zombie/fx_zombie_body_wtr_billowing");
	level._effect["rise_dust_water"]			= LoadFX("maps/zombie/fx_zombie_body_wtr_falling");

	level._effect["rise_burst"]					= LoadFX("maps/zombie/fx_mp_zombie_hand_dirt_burst");
	level._effect["rise_billow"]				= LoadFX("maps/zombie/fx_mp_zombie_body_dirt_billowing");
	level._effect["rise_dust"]					= LoadFX("maps/zombie/fx_mp_zombie_body_dust_falling");	

	level._effect["fall_burst"]					= LoadFX("maps/zombie/fx_mp_zombie_hand_dirt_burst");
	level._effect["fall_billow"]				= LoadFX("maps/zombie/fx_mp_zombie_body_dirt_billowing");
	level._effect["fall_dust"]					= LoadFX("maps/zombie/fx_mp_zombie_body_dust_falling");	

	// Flamethrower
	level._effect["character_fire_pain_sm"]     = LoadFX( "env/fire/fx_fire_player_sm_1sec" );
	level._effect["character_fire_death_sm"]    = LoadFX( "env/fire/fx_fire_player_md" );
	level._effect["character_fire_death_torso"] = LoadFX( "env/fire/fx_fire_player_torso" );

	level._effect["def_explosion"]				= LoadFX("explosions/fx_default_explosion");
	level._effect["betty_explode"]				= LoadFX("weapon/bouncing_betty/fx_explosion_betty_generic");
}


// zombie specific anims
init_standard_zombie_anims()
{
	// deaths
	level.scr_anim["zombie"]["death1"] 	= %ai_zombie_death_v1;
	level.scr_anim["zombie"]["death2"] 	= %ai_zombie_death_v2;
	level.scr_anim["zombie"]["death3"] 	= %ai_zombie_crawl_death_v1;
	level.scr_anim["zombie"]["death4"] 	= %ai_zombie_crawl_death_v2;

	// run cycles
	
	level.scr_anim["zombie"]["walk1"] 	= %ai_zombie_walk_v1;
	level.scr_anim["zombie"]["walk2"] 	= %ai_zombie_walk_v2;
	level.scr_anim["zombie"]["walk3"] 	= %ai_zombie_walk_v3;
	level.scr_anim["zombie"]["walk4"] 	= %ai_zombie_walk_v4;
	level.scr_anim["zombie"]["walk5"] 	= %ai_zombie_walk_v6;
	level.scr_anim["zombie"]["walk6"] 	= %ai_zombie_walk_v7;
	level.scr_anim["zombie"]["walk7"] 	= %ai_zombie_walk_v9;	//was goose step walk - overridden in theatre only (v8)
	level.scr_anim["zombie"]["walk8"] 	= %ai_zombie_walk_v9;

	level.scr_anim["zombie"]["run1"] 	= %ai_zombie_walk_fast_v1;
	level.scr_anim["zombie"]["run2"] 	= %ai_zombie_walk_fast_v2;
	level.scr_anim["zombie"]["run3"] 	= %ai_zombie_walk_fast_v3;
	level.scr_anim["zombie"]["run4"] 	= %ai_zombie_run_v2;
	level.scr_anim["zombie"]["run5"] 	= %ai_zombie_run_v4;
	level.scr_anim["zombie"]["run6"] 	= %ai_zombie_run_v3;
	//level.scr_anim["zombie"]["run4"] 	= %ai_zombie_run_v1;
	//level.scr_anim["zombie"]["run6"] 	= %ai_zombie_run_v4;

	level.scr_anim["zombie"]["sprint1"] = %ai_zombie_sprint_v1;
	level.scr_anim["zombie"]["sprint2"] = %ai_zombie_sprint_v2;
	level.scr_anim["zombie"]["sprint3"] = %ai_zombie_sprint_v1;
	level.scr_anim["zombie"]["sprint4"] = %ai_zombie_sprint_v2;
	//level.scr_anim["zombie"]["sprint3"] = %ai_zombie_sprint_v3;
	//level.scr_anim["zombie"]["sprint3"] = %ai_zombie_sprint_v4;
	//level.scr_anim["zombie"]["sprint4"] = %ai_zombie_sprint_v5;

	// run cycles in prone
	level.scr_anim["zombie"]["crawl1"] 	= %ai_zombie_crawl;
	level.scr_anim["zombie"]["crawl2"] 	= %ai_zombie_crawl_v1;
	level.scr_anim["zombie"]["crawl3"] 	= %ai_zombie_crawl_v2;
	level.scr_anim["zombie"]["crawl4"] 	= %ai_zombie_crawl_v3;
	level.scr_anim["zombie"]["crawl5"] 	= %ai_zombie_crawl_v4;
	level.scr_anim["zombie"]["crawl6"] 	= %ai_zombie_crawl_v5;
	level.scr_anim["zombie"]["crawl_hand_1"] = %ai_zombie_walk_on_hands_a;
	level.scr_anim["zombie"]["crawl_hand_2"] = %ai_zombie_walk_on_hands_b;

	level.scr_anim["zombie"]["crawl_sprint1"] 	= %ai_zombie_crawl_sprint;
	level.scr_anim["zombie"]["crawl_sprint2"] 	= %ai_zombie_crawl_sprint_1;
	level.scr_anim["zombie"]["crawl_sprint3"] 	= %ai_zombie_crawl_sprint_2;

	if( !isDefined( level._zombie_melee ) )
	{
		level._zombie_melee = [];
	}
	if( !isDefined( level._zombie_walk_melee ) )
	{
		level._zombie_walk_melee = [];
	}
	if( !isDefined( level._zombie_run_melee ) )
	{
		level._zombie_run_melee = [];
	}

	level._zombie_melee["zombie"] = [];
	level._zombie_walk_melee["zombie"] = [];
	level._zombie_run_melee["zombie"] = [];


	level._zombie_melee["zombie"][0] 				= %ai_zombie_attack_v2;				// slow swipes
	level._zombie_melee["zombie"][1]				= %ai_zombie_attack_v4;				// single left swipe
	level._zombie_melee["zombie"][2]				= %ai_zombie_attack_v6;				// wierd single
level._zombie_melee["zombie"][3] 				= %ai_zombie_attack_v1;				// DOUBLE SWIPE
level._zombie_melee["zombie"][4] 				= %ai_zombie_attack_forward_v1;		// DOUBLE SWIPE
level._zombie_melee["zombie"][5] 				= %ai_zombie_attack_forward_v2;		// slow DOUBLE SWIPE
	
	level._zombie_run_melee["zombie"][0]				=	%ai_zombie_run_attack_v1;	// fast single right
	level._zombie_run_melee["zombie"][1]				=	%ai_zombie_run_attack_v2;	// fast double swipe
	level._zombie_run_melee["zombie"][2]				=	%ai_zombie_run_attack_v3;	// fast swipe

	if( isDefined( level.zombie_anim_override ) )
	{
		[[ level.zombie_anim_override ]]();
	}

	// melee in walk
	level._zombie_walk_melee["zombie"][0]			= %ai_zombie_walk_attack_v1;	// fast single right swipe
	level._zombie_walk_melee["zombie"][1]			= %ai_zombie_walk_attack_v2;	// slow right/left single hit
	level._zombie_walk_melee["zombie"][2]			= %ai_zombie_walk_attack_v3;	// fast single left swipe
	level._zombie_walk_melee["zombie"][3]			= %ai_zombie_walk_attack_v4;	// slow single right swipe

	// melee in crawl
	if( !isDefined( level._zombie_melee_crawl ) )
	{
		level._zombie_melee_crawl = [];
	}
	level._zombie_melee_crawl["zombie"] = [];
	level._zombie_melee_crawl["zombie"][0] 		= %ai_zombie_attack_crawl; 
	level._zombie_melee_crawl["zombie"][1] 		= %ai_zombie_attack_crawl_lunge;

	if( !isDefined( level._zombie_stumpy_melee ) )
	{
		level._zombie_stumpy_melee = [];
	}
	level._zombie_stumpy_melee["zombie"] = [];
	level._zombie_stumpy_melee["zombie"][0] = %ai_zombie_walk_on_hands_shot_a;
	level._zombie_stumpy_melee["zombie"][1] = %ai_zombie_walk_on_hands_shot_b;
	//level._zombie_melee_crawl["zombie"][2]		= %ai_zombie_crawl_attack_A;

	// tesla deaths
	if( !isDefined( level._zombie_tesla_death ) )
	{
		level._zombie_tesla_death = [];
	}
	level._zombie_tesla_death["zombie"] = [];
	level._zombie_tesla_death["zombie"][0] = %ai_zombie_tesla_death_a;
	level._zombie_tesla_death["zombie"][1] = %ai_zombie_tesla_death_b;
	level._zombie_tesla_death["zombie"][2] = %ai_zombie_tesla_death_c;
	level._zombie_tesla_death["zombie"][3] = %ai_zombie_tesla_death_d;
	level._zombie_tesla_death["zombie"][4] = %ai_zombie_tesla_death_e;

	if( !isDefined( level._zombie_tesla_crawl_death ) )
	{
		level._zombie_tesla_crawl_death = [];
	}
	level._zombie_tesla_crawl_death["zombie"] = [];
	level._zombie_tesla_crawl_death["zombie"][0] = %ai_zombie_tesla_crawl_death_a;
	level._zombie_tesla_crawl_death["zombie"][1] = %ai_zombie_tesla_crawl_death_b;

	// thundergun knockdowns and getups
	if( !isDefined( level._zombie_knockdowns ) )
	{
		level._zombie_knockdowns = [];
	}
	level._zombie_knockdowns["zombie"] = [];
	level._zombie_knockdowns["zombie"]["front"] = [];

	level._zombie_knockdowns["zombie"]["front"]["no_legs"] = [];
	level._zombie_knockdowns["zombie"]["front"]["no_legs"][0] = %ai_zombie_thundergun_hit_armslegsforward;
	level._zombie_knockdowns["zombie"]["front"]["no_legs"][1] = %ai_zombie_thundergun_hit_doublebounce;
	level._zombie_knockdowns["zombie"]["front"]["no_legs"][2] = %ai_zombie_thundergun_hit_forwardtoface;

	level._zombie_knockdowns["zombie"]["front"]["has_legs"] = [];

	level._zombie_knockdowns["zombie"]["front"]["has_legs"][0] = %ai_zombie_thundergun_hit_armslegsforward;
	level._zombie_knockdowns["zombie"]["front"]["has_legs"][1] = %ai_zombie_thundergun_hit_doublebounce;
	level._zombie_knockdowns["zombie"]["front"]["has_legs"][2] = %ai_zombie_thundergun_hit_upontoback;
	level._zombie_knockdowns["zombie"]["front"]["has_legs"][3] = %ai_zombie_thundergun_hit_forwardtoface;
	level._zombie_knockdowns["zombie"]["front"]["has_legs"][4] = %ai_zombie_thundergun_hit_armslegsforward;
	level._zombie_knockdowns["zombie"]["front"]["has_legs"][5] = %ai_zombie_thundergun_hit_forwardtoface;
	level._zombie_knockdowns["zombie"]["front"]["has_legs"][6] = %ai_zombie_thundergun_hit_stumblefall;
	level._zombie_knockdowns["zombie"]["front"]["has_legs"][7] = %ai_zombie_thundergun_hit_armslegsforward;
	level._zombie_knockdowns["zombie"]["front"]["has_legs"][8] = %ai_zombie_thundergun_hit_doublebounce;
	level._zombie_knockdowns["zombie"]["front"]["has_legs"][9] = %ai_zombie_thundergun_hit_upontoback;
	level._zombie_knockdowns["zombie"]["front"]["has_legs"][10] = %ai_zombie_thundergun_hit_forwardtoface;
	level._zombie_knockdowns["zombie"]["front"]["has_legs"][11] = %ai_zombie_thundergun_hit_armslegsforward;
	level._zombie_knockdowns["zombie"]["front"]["has_legs"][12] = %ai_zombie_thundergun_hit_forwardtoface;
	level._zombie_knockdowns["zombie"]["front"]["has_legs"][13] = %ai_zombie_thundergun_hit_deadfallknee;
	level._zombie_knockdowns["zombie"]["front"]["has_legs"][14] = %ai_zombie_thundergun_hit_armslegsforward;
	level._zombie_knockdowns["zombie"]["front"]["has_legs"][15] = %ai_zombie_thundergun_hit_doublebounce;
	level._zombie_knockdowns["zombie"]["front"]["has_legs"][16] = %ai_zombie_thundergun_hit_upontoback;
	level._zombie_knockdowns["zombie"]["front"]["has_legs"][17] = %ai_zombie_thundergun_hit_forwardtoface;
	level._zombie_knockdowns["zombie"]["front"]["has_legs"][18] = %ai_zombie_thundergun_hit_armslegsforward;
	level._zombie_knockdowns["zombie"]["front"]["has_legs"][19] = %ai_zombie_thundergun_hit_forwardtoface;
	level._zombie_knockdowns["zombie"]["front"]["has_legs"][20] = %ai_zombie_thundergun_hit_flatonback;

	level._zombie_knockdowns["zombie"]["left"] = [];
	level._zombie_knockdowns["zombie"]["left"][0] = %ai_zombie_thundergun_hit_legsout_right;

	level._zombie_knockdowns["zombie"]["right"] = [];
	level._zombie_knockdowns["zombie"]["right"][0] = %ai_zombie_thundergun_hit_legsout_left;

	level._zombie_knockdowns["zombie"]["back"] = [];
	level._zombie_knockdowns["zombie"]["back"][0] = %ai_zombie_thundergun_hit_faceplant;

	if( !isDefined( level._zombie_getups ) )
	{
		level._zombie_getups = [];
	}
	level._zombie_getups["zombie"] = [];
	level._zombie_getups["zombie"]["back"] = [];

	level._zombie_getups["zombie"]["back"]["early"] = [];
	level._zombie_getups["zombie"]["back"]["early"][0] = %ai_zombie_thundergun_getup_b;
	level._zombie_getups["zombie"]["back"]["early"][1] = %ai_zombie_thundergun_getup_c;

	level._zombie_getups["zombie"]["back"]["late"] = [];
	level._zombie_getups["zombie"]["back"]["late"][0] = %ai_zombie_thundergun_getup_b;
	level._zombie_getups["zombie"]["back"]["late"][1] = %ai_zombie_thundergun_getup_c;
	level._zombie_getups["zombie"]["back"]["late"][2] = %ai_zombie_thundergun_getup_quick_b;
	level._zombie_getups["zombie"]["back"]["late"][3] = %ai_zombie_thundergun_getup_quick_c;

	level._zombie_getups["zombie"]["belly"] = [];

	level._zombie_getups["zombie"]["belly"]["early"] = [];
	level._zombie_getups["zombie"]["belly"]["early"][0] = %ai_zombie_thundergun_getup_a;

	level._zombie_getups["zombie"]["belly"]["late"] = [];
	level._zombie_getups["zombie"]["belly"]["late"][0] = %ai_zombie_thundergun_getup_a;
	level._zombie_getups["zombie"]["belly"]["late"][1] = %ai_zombie_thundergun_getup_quick_a;

	// freezegun deaths
	if( !isDefined( level._zombie_freezegun_death ) )
	{
		level._zombie_freezegun_death = [];
	}
	level._zombie_freezegun_death["zombie"] = [];
	level._zombie_freezegun_death["zombie"][0] = %ai_zombie_freeze_death_a;
	level._zombie_freezegun_death["zombie"][1] = %ai_zombie_freeze_death_b;
	level._zombie_freezegun_death["zombie"][2] = %ai_zombie_freeze_death_c;
	level._zombie_freezegun_death["zombie"][3] = %ai_zombie_freeze_death_d;
	level._zombie_freezegun_death["zombie"][4] = %ai_zombie_freeze_death_e;

	if( !isDefined( level._zombie_freezegun_death_missing_legs ) )
	{
		level._zombie_freezegun_death_missing_legs = [];
	}
	level._zombie_freezegun_death_missing_legs["zombie"] = [];
	level._zombie_freezegun_death_missing_legs["zombie"][0] = %ai_zombie_crawl_freeze_death_01;
	level._zombie_freezegun_death_missing_legs["zombie"][1] = %ai_zombie_crawl_freeze_death_02;

	// deaths
	if( !isDefined( level._zombie_deaths ) )
	{
		level._zombie_deaths = [];
	}
	level._zombie_deaths["zombie"] = [];
	level._zombie_deaths["zombie"][0] = %ch_dazed_a_death;
	level._zombie_deaths["zombie"][1] = %ch_dazed_b_death;
	level._zombie_deaths["zombie"][2] = %ch_dazed_c_death;
	level._zombie_deaths["zombie"][3] = %ch_dazed_d_death;

	/*
	ground crawl
	*/

	if( !isDefined( level._zombie_rise_anims ) )
	{
		level._zombie_rise_anims = [];
	}

	// set up the arrays
	level._zombie_rise_anims["zombie"] = [];

	//level._zombie_rise_anims["zombie"][1]["walk"][0]		= %ai_zombie_traverse_ground_v1_crawl;
	level._zombie_rise_anims["zombie"][1]["walk"][0]		= %ai_zombie_traverse_ground_v1_walk;

	//level._zombie_rise_anims["zombie"][1]["run"][0]		= %ai_zombie_traverse_ground_v1_crawlfast;
	level._zombie_rise_anims["zombie"][1]["run"][0]		= %ai_zombie_traverse_ground_v1_run;

	level._zombie_rise_anims["zombie"][1]["sprint"][0]	= %ai_zombie_traverse_ground_climbout_fast;

	//level._zombie_rise_anims["zombie"][2]["walk"][0]		= %ai_zombie_traverse_ground_v2_walk;	//!broken
	level._zombie_rise_anims["zombie"][2]["walk"][0]		= %ai_zombie_traverse_ground_v2_walk_altA;
	//level._zombie_rise_anims["zombie"][2]["walk"][2]		= %ai_zombie_traverse_ground_v2_walk_altB;//!broken

	// ground crawl death
	if( !isDefined( level._zombie_rise_death_anims ) )
	{
		level._zombie_rise_death_anims = [];
	}
	
	level._zombie_rise_death_anims["zombie"] = [];

	level._zombie_rise_death_anims["zombie"][1]["in"][0]		= %ai_zombie_traverse_ground_v1_deathinside;
	level._zombie_rise_death_anims["zombie"][1]["in"][1]		= %ai_zombie_traverse_ground_v1_deathinside_alt;

	level._zombie_rise_death_anims["zombie"][1]["out"][0]		= %ai_zombie_traverse_ground_v1_deathoutside;
	level._zombie_rise_death_anims["zombie"][1]["out"][1]		= %ai_zombie_traverse_ground_v1_deathoutside_alt;

	level._zombie_rise_death_anims["zombie"][2]["in"][0]		= %ai_zombie_traverse_ground_v2_death_low;
	level._zombie_rise_death_anims["zombie"][2]["in"][1]		= %ai_zombie_traverse_ground_v2_death_low_alt;

	level._zombie_rise_death_anims["zombie"][2]["out"][0]		= %ai_zombie_traverse_ground_v2_death_high;
	level._zombie_rise_death_anims["zombie"][2]["out"][1]		= %ai_zombie_traverse_ground_v2_death_high_alt;
	
	//taunts
	if( !isDefined( level._zombie_run_taunt ) )
	{
		level._zombie_run_taunt = [];
	}
	if( !isDefined( level._zombie_board_taunt ) )
	{
		level._zombie_board_taunt = [];
	}
	level._zombie_run_taunt["zombie"] = [];
	level._zombie_board_taunt["zombie"] = [];
	
	//level._zombie_taunt["zombie"][0] = %ai_zombie_taunts_1;
	//level._zombie_taunt["zombie"][1] = %ai_zombie_taunts_4;
	//level._zombie_taunt["zombie"][2] = %ai_zombie_taunts_5b;
	//level._zombie_taunt["zombie"][3] = %ai_zombie_taunts_5c;
	//level._zombie_taunt["zombie"][4] = %ai_zombie_taunts_5d;
	//level._zombie_taunt["zombie"][5] = %ai_zombie_taunts_5e;
	//level._zombie_taunt["zombie"][6] = %ai_zombie_taunts_5f;
	//level._zombie_taunt["zombie"][7] = %ai_zombie_taunts_7;
	//level._zombie_taunt["zombie"][8] = %ai_zombie_taunts_9;
	//level._zombie_taunt["zombie"][8] = %ai_zombie_taunts_11;
	//level._zombie_taunt["zombie"][8] = %ai_zombie_taunts_12;
	
	level._zombie_board_taunt["zombie"][0] = %ai_zombie_taunts_4;
	level._zombie_board_taunt["zombie"][1] = %ai_zombie_taunts_7;
	level._zombie_board_taunt["zombie"][2] = %ai_zombie_taunts_9;
	level._zombie_board_taunt["zombie"][3] = %ai_zombie_taunts_5b;
	level._zombie_board_taunt["zombie"][4] = %ai_zombie_taunts_5c;
	level._zombie_board_taunt["zombie"][5] = %ai_zombie_taunts_5d;
	level._zombie_board_taunt["zombie"][6] = %ai_zombie_taunts_5e;
	level._zombie_board_taunt["zombie"][7] = %ai_zombie_taunts_5f;
}

init_anims()
{
	init_standard_zombie_anims();
}

// Initialize any animscript related variables
init_animscripts()
{
	// Setup the animscripts, then override them (we call this just incase an AI has not yet spawned)
	animscripts\zombie_init::firstInit();

	anim.idleAnimArray		["stand"] = [];
	anim.idleAnimWeights	["stand"] = [];
	anim.idleAnimArray		["stand"][0][0] 	= %ai_zombie_idle_v1_delta;
	anim.idleAnimWeights	["stand"][0][0] 	= 10;

	anim.idleAnimArray		["crouch"] = [];
	anim.idleAnimWeights	["crouch"] = [];	
	anim.idleAnimArray		["crouch"][0][0] 	= %ai_zombie_idle_crawl_delta;
	anim.idleAnimWeights	["crouch"][0][0] 	= 10;
}

// Handles the intro screen
zombie_intro_screen( string1, string2, string3, string4, string5 )
{
	flag_wait( "all_players_connected" );
}

players_playing()
{
	// initialize level.players_playing
	players = get_players();
	level.players_playing = players.size;

	wait( 20 );

	players = get_players();
	level.players_playing = players.size;
}


//	Init some additional settings based on difficulty and number of players
//
difficulty_init()
{
	flag_wait( "all_players_connected" );

	difficulty =1;
	table	= "mp/zombiemode.csv";
	column	= int(difficulty)+1;
	players = get_players();
	points	= 500;


	// Get individual starting points
	points = set_zombie_var( ("zombie_score_start_"+players.size+"p"), 3000, false, column );
/#
	if( GetDvarInt( #"zombie_cheat" ) >= 1 )
	{
		points = 100000;
	}
#/
	for ( p=0; p<players.size; p++ )
	{
		players[p].score = points;
		players[p].score_total = players[p].score; 
		players[p].old_score = players[p].score;
	}

	// Get team starting points
	points = set_zombie_var( ("zombie_team_score_start_"+players.size+"p"), 2000, false, column );
/#
	if( GetDvarInt( #"zombie_cheat" ) >= 1 )
	{
		points = 100000;
	}
#/
	for ( tp = 0; tp<level.team_pool.size; tp++ )
	{
		pool = level.team_pool[ tp ];
		pool.score			= points;
		pool.old_score		= pool.score;
		pool.score_total	= pool.score;
	}

	// Other difficulty-specific changes
	switch ( difficulty )
	{
	case "0":
	case "1":
		break;
	case "2":
		level.first_round	= false;
		level.round_number	= 8;
		break;
	case "3":
		level.first_round	= false;
		level.round_number	= 18;
		break;
	default:
		break;
	}

	if( level.mutators["mutator_quickStart"] )
	{
		level.first_round	= false;
		level.round_number	= 5;
	}
}


//
// NETWORK SECTION ====================================================================== //
//

watchTakenDamage()
{
	self endon( "disconnect" ); 
	self endon( "death" );

	self.has_taken_damage = false;
	while(1)
	{
		self waittill("damage", damage_amount );

		if ( 0 < damage_amount )
		{
			self.has_taken_damage = true;
			return;
		}
	}
}

onPlayerConnect()
{
	for( ;; )
	{
		level waittill( "connecting", player ); 

		player.entity_num = player GetEntityNumber(); 
		player thread onPlayerSpawned(); 
		player thread onPlayerDisconnect(); 
		player thread player_revive_monitor();

		player freezecontrols( true );

		player thread watchTakenDamage();

		player.score = 0; 
		player.score_total = player.score; 
		player.old_score = player.score; 

		player.is_zombie = false; 
		player.initialized = false;
		player.zombification_time = 0;
		player.enableText = true;

		player.team_num = 0;

		player setTeamForEntity( "allies" );

		//player maps\_zombiemode_protips::player_init();
		
		// DCS 090910: now that player can destroy some barricades before set.
		player thread maps\_zombiemode_blockers::rebuild_barrier_reward_reset();		
	}
}

onPlayerConnect_clientDvars()
{
	self SetClientDvars( "cg_deadChatWithDead", "1",
		"cg_deadChatWithTeam", "1",
		"cg_deadHearTeamLiving", "1",
		"cg_deadHearAllLiving", "1",
		"cg_everyoneHearsEveryone", "1",
		"compass", "0",
		"hud_showStance", "0",
		"cg_thirdPerson", "0",
		"cg_fov", "65",
		"cg_thirdPersonAngle", "0",
		"ammoCounterHide", "1",
		"miniscoreboardhide", "1",
		"cg_drawSpectatorMessages", "0",
		"ui_hud_hardcore", "0",
		"playerPushAmount", "1" );

	self SetDepthOfField( 0, 0, 512, 4000, 4, 0 );

	// Enabling the FPS counter in ship for now
	//self setclientdvar( "cg_drawfps", "1" );
	
	self setClientDvar( "aim_lockon_pitch_strength", 0.0 );


	
	if(!level.wii)
	{
		//self SetClientDvar("r_enablePlayerShadow", 1); 
	}

	self SetClientDvar("hud_enemy_counter_value", "");
	self SetClientDvar("hud_sph", "");
	self SetClientDvar("hud_zone_name", "");
}



checkForAllDead()
{
	players = get_players();
	count = 0;
	for( i = 0; i < players.size; i++ )
	{
		if( !(players[i] maps\_laststand::player_is_in_laststand()) && !(players[i].sessionstate == "spectator") )
		{
			count++;
		}
	}
	
	if( count==0 )
	{
		level notify( "end_game" );
	}
}
	

onPlayerDisconnect()
{
	self waittill( "disconnect" ); 
	self remove_from_spectate_list();
	self checkForAllDead();
}


//
//	Runs when the player spawns into the map
//	self is the player.surprise!
//
onPlayerSpawned()
{
	self endon( "disconnect" ); 

	for( ;; )
	{
		self waittill( "spawned_player" ); 
		
		self freezecontrols( false );

		self init_player_offhand_weapons();

		self enablehealthshield( false );
/#
		if ( GetDvarInt( #"zombie_cheat" ) >= 1 && GetDvarInt( #"zombie_cheat" ) <= 3 ) 
		{
			self EnableInvulnerability();
		}
#/

		self PlayerKnockback( false );

		self SetClientDvars( "cg_thirdPerson", "0",
			"cg_fov", "75",
			"cg_thirdPersonAngle", "0", 
			"player_backSpeedScale", "1",
			"player_strafeSpeedScale", "1");

		self setClientDvar("hud_zone_name_on_game", 1);
		self setClientDvar("hud_health_bar_on_game", 1);
		self SetDepthOfField( 0, 0, 512, 4000, 4, 0 );

		self cameraactivate(false);

		self add_to_spectate_list();
		
		self.num_perks = 0;
		self.on_lander_last_stand = undefined;
		
		if ( is_true( level.player_out_of_playable_area_monitor ) )
		{
			self thread player_out_of_playable_area_monitor();
		}

		if ( is_true( level.player_too_many_weapons_monitor ) )
		{
			self thread [[level.player_too_many_weapons_monitor_func]]();
		}

		if( isdefined( self.initialized ) )
		{
			if( self.initialized == false )
			{
				self.initialized = true; 
				
				self freezecontrols( true ); // first spawn only, intro_black_screen will pull them out of it

				// ww: set the is_drinking variable
				self.is_drinking = 0;

				// set the initial score on the hud		
				self maps\_zombiemode_score::set_player_score_hud( true ); 
				self thread player_zombie_breadcrumb();				
			
				// This will keep checking to see if you're trying to use an ability.
				//self thread maps\_zombiemode_ability::hardpointItemWaiter();

				//self thread maps\_zombiemode_ability::hardPointItemSelector();

				//Init stat tracking variables
				self.stats["kills"] = 0;
				self.stats["score"] = 0;
				self.stats["downs"] = 0;
				self.stats["revives"] = 0;
				self.stats["perks"] = 0;
				self.stats["headshots"] = 0;
				self.stats["zombie_gibs"] = 0;
				
				//track damage taken by this player
				self.stats["damage_taken"] = 0;
				
				//track player distance traveled
				self.stats["distance_traveled"] = 0;
				self thread player_monitor_travel_dist();	

				self thread player_grenade_watcher();

				
				//Practice Stuff
				if ( level.script == "zombie_cod5_factory" )
					self.score = 651000;
				else if ( level.script == "zombie_temple" )
					self.score = 505000;
				else
					self.score = 500000;

				level.chest_moves = 1;

				self thread watch_for_trade();

				//self thread hud_health_bar();
				self thread insta_kill_rounds();				
				self thread give_player_perks();
				self thread give_player_weapons();
				self thread set_player_weapon();
				self thread zone_hud();
				self thread health_bar_hud();
				self thread hud_zombies_remaining();
				self thread hud_sph();
			}
		}
	}
}


spawn_life_brush( origin, radius, height )
{
	life_brush = spawn( "trigger_radius", origin, 0, radius, height );
	life_brush.script_noteworthy = "life_brush";
	
	return life_brush;
}


in_life_brush()
{
	life_brushes = getentarray( "life_brush", "script_noteworthy" );

	if ( !IsDefined( life_brushes ) )
	{
		return false;
	}
	
	for ( i = 0; i < life_brushes.size; i++ )
	{

		if ( self IsTouching( life_brushes[i] ) )
		{
			return true;
		}
	}

	return false;
}


spawn_kill_brush( origin, radius, height )
{
	kill_brush = spawn( "trigger_radius", origin, 0, radius, height );
	kill_brush.script_noteworthy = "kill_brush";
	
	return kill_brush;
}


in_kill_brush()
{
	kill_brushes = getentarray( "kill_brush", "script_noteworthy" );

	if ( !IsDefined( kill_brushes ) )
	{
		return false;
	}
	
	for ( i = 0; i < kill_brushes.size; i++ )
	{

		if ( self IsTouching( kill_brushes[i] ) )
		{
			return true;
		}
	}

	return false;
}


in_enabled_playable_area()
{
	playable_area = getentarray( "player_volume", "script_noteworthy" );

	if( !IsDefined( playable_area ) )
	{
		return false;
	}
	
	for ( i = 0; i < playable_area.size; i++ )
	{
		if ( maps\_zombiemode_zone_manager::zone_is_enabled( playable_area[i].targetname ) && self IsTouching( playable_area[i] ) )
		{
			return true;
		}
	}

	return false;
}


get_player_out_of_playable_area_monitor_wait_time()
{
/#
	if ( is_true( level.check_kill_thread_every_frame ) )
	{
		return 0.05;
	}
#/

	return 3;
}


player_out_of_playable_area_monitor()
{
	self notify( "stop_player_out_of_playable_area_monitor" );
	self endon( "stop_player_out_of_playable_area_monitor" );
	self endon( "disconnect" );
	level endon( "end_game" );

	// load balancing
	wait( (0.15 * self GetEntityNumber()) );

	while ( true )
	{
		// skip over players in spectate, otherwise Sam keeps laughing every 3 seconds since their corpse is still invisibly in a kill area
		if ( self.sessionstate == "spectator" )
		{
			wait( get_player_out_of_playable_area_monitor_wait_time() );
			continue;
		}

		if ( !self in_life_brush() && (self in_kill_brush() || !self in_enabled_playable_area()) )
		{
			if ( !isdefined( level.player_out_of_playable_area_monitor_callback ) || self [[level.player_out_of_playable_area_monitor_callback]]() )
			{
/#
				//iprintlnbold( "out of playable" );
				if ( isdefined( self isinmovemode( "ufo", "noclip" ) ) || is_true( level.disable_kill_thread ) || GetDvarInt( "zombie_cheat" ) > 0 )
				{
					wait( get_player_out_of_playable_area_monitor_wait_time() );
					continue;
				}
#/
 				if( is_true( level.player_4_vox_override ) )
				{
					self playlocalsound( "zmb_laugh_rich" );
				}
				else
				{
					self playlocalsound( "zmb_laugh_child" );	
				}
				
				wait( 0.5 );

				if ( getplayers().size == 1 && flag( "solo_game" ) && is_true( self.waiting_to_revive ) )
				{
					level notify( "end_game" );
				}
				else
				{
					self.lives = 0;
					self dodamage( self.health + 1000, self.origin );
					self.bleedout_time = 0;
				}
			}
		}

		wait( get_player_out_of_playable_area_monitor_wait_time() );
	}
}


get_player_too_many_weapons_monitor_wait_time()
{
	return 3;
}


player_too_many_weapons_monitor_takeaway_simultaneous( primary_weapons_to_take )
{
	self endon( "player_too_many_weapons_monitor_takeaway_sequence_done" );

	self waittill_any( "player_downed", "replace_weapon_powerup" );

	for ( i = 0; i < primary_weapons_to_take.size; i++ )
	{
		self TakeWeapon( primary_weapons_to_take[i] );
	}

	self maps\_zombiemode_score::minus_to_player_score( self.score );
	self GiveWeapon( "m1911_zm" );
	if ( !self maps\_laststand::player_is_in_laststand() )
	{
		self decrement_is_drinking();
	}
	else if ( flag( "solo_game" ) )
	{
		self.score_lost_when_downed = 0;
	}

	self notify( "player_too_many_weapons_monitor_takeaway_sequence_done" );
}


player_too_many_weapons_monitor_takeaway_sequence( primary_weapons_to_take )
{
	self thread player_too_many_weapons_monitor_takeaway_simultaneous( primary_weapons_to_take );

	self endon( "player_downed" );
	self endon( "replace_weapon_powerup" );

	self increment_is_drinking();
	score_decrement = round_up_to_ten( int( self.score / (primary_weapons_to_take.size + 1) ) );

	for ( i = 0; i < primary_weapons_to_take.size; i++ )
	{
		if( is_true( level.player_4_vox_override ) )
		{
			self playlocalsound( "zmb_laugh_rich" );
		}
		else
		{
			self playlocalsound( "zmb_laugh_child" );	
		}
		self SwitchToWeapon( primary_weapons_to_take[i] );
		self maps\_zombiemode_score::minus_to_player_score( score_decrement );
		wait( 3 );

		self TakeWeapon( primary_weapons_to_take[i] );
	}

	if( is_true( level.player_4_vox_override ) )
	{
		self playlocalsound( "zmb_laugh_rich" );
	}
	else
	{
		self playlocalsound( "zmb_laugh_child" );	
	}
	self maps\_zombiemode_score::minus_to_player_score( self.score );
	wait( 1 );
	self GiveWeapon( "m1911_zm" );
	self SwitchToWeapon( "m1911_zm" );
	self decrement_is_drinking();

	self notify( "player_too_many_weapons_monitor_takeaway_sequence_done" );
}


player_too_many_weapons_monitor()
{
	self notify( "stop_player_too_many_weapons_monitor" );
	self endon( "stop_player_too_many_weapons_monitor" );
	self endon( "disconnect" );
	level endon( "end_game" );

	// load balancing
	wait( (0.15 * self GetEntityNumber()) );

	while ( true )
	{
		if ( self has_powerup_weapon() || self maps\_laststand::player_is_in_laststand() || self.sessionstate == "spectator" )
		{
			wait( get_player_too_many_weapons_monitor_wait_time() );
			continue;
		}

/#
		if ( GetDvarInt( "zombie_cheat" ) > 0 )
		{
			wait( get_player_too_many_weapons_monitor_wait_time() );
			continue;
		}
#/

		primary_weapons_to_take = [];
		weapon_limit = 2;
		if ( self HasPerk( "specialty_additionalprimaryweapon" ) )
		{
			weapon_limit = 3;
		}

		primaryWeapons = self GetWeaponsListPrimaries();
		for ( i = 0; i < primaryWeapons.size; i++ )
		{
			if ( maps\_zombiemode_weapons::is_weapon_included( primaryWeapons[i] ) || maps\_zombiemode_weapons::is_weapon_upgraded( primaryWeapons[i] ) )
			{
				primary_weapons_to_take[primary_weapons_to_take.size] = primaryWeapons[i];
			}
		}

		if ( primary_weapons_to_take.size > weapon_limit )
		{
			if ( !isdefined( level.player_too_many_weapons_monitor_callback ) || self [[level.player_too_many_weapons_monitor_callback]]( primary_weapons_to_take ) )
			{
				self thread player_too_many_weapons_monitor_takeaway_sequence( primary_weapons_to_take );
				self waittill( "player_too_many_weapons_monitor_takeaway_sequence_done" );
			}
		}

		wait( get_player_too_many_weapons_monitor_wait_time() );
	}
}


player_monitor_travel_dist()
{
	self endon("disconnect");
	
	prevpos = self.origin;
	while(1)
	{
		wait .1;

		self.stats["distance_traveled"] += distance( self.origin, prevpos );
		prevpos = self.origin;
	}
}

player_grenade_watcher()
{
	self endon( "disconnect" );

	while ( 1 )
	{
		self waittill( "grenade_fire", grenade, weapName );

		if( isdefined( grenade ) && isalive( grenade ) )
		{
			grenade.team = self.team;
		}
	}
}

player_prevent_damage( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, sWeapon, vPoint, vDir, sHitLoc, modelIndex, psOffsetTime )
{
	if ( eInflictor == self || eAttacker == self )
	{
		return false;
	}

	if ( isdefined( eInflictor ) && isdefined( eInflictor.team ) )
	{
		if ( eInflictor.team == self.team )
		{
			return true;
		}
	}

	return false;
}

//
//	Keep track of players going down and getting revived
player_revive_monitor()
{
	self endon( "disconnect" ); 

	while (1)
	{
		self waittill( "player_revived", reviver );	
        
        //AYERS: Working on Laststand Audio
        //self clientnotify( "revived" );
        
		bbPrint( "zombie_playerdeaths: round %d playername %s deathtype revived x %f y %f z %f", level.round_number, self.playername, self.origin );

		self thread give_player_perks();

		//self laststand_giveback_player_perks();

		if ( IsDefined(reviver) )
		{
			self maps\_zombiemode_audio::create_and_play_dialog( "general", "revive_up" );
			
			//reviver maps\_zombiemode_rank::giveRankXp( "revive" );
			//maps\_zombiemode_challenges::doMissionCallback( "zm_revive", reviver );

			// Check to see how much money you lost from being down.
			points = self.score_lost_when_downed;
			reviver maps\_zombiemode_score::player_add_points( "reviver", points );
			self.score_lost_when_downed = 0;
		}
	}
}


// self = a player
// If the player has just 1 perk, they wil always get it back
// If the player has more than 1 perk, they will lose a single perk
laststand_giveback_player_perks()
{
	if ( IsDefined( self.laststand_perks ) )
	{
		// Calculate a lost perk index
		lost_perk_index = int( -1 );
		if( self.laststand_perks.size > 1 )
		{
			lost_perk_index = RandomInt( self.laststand_perks.size-1 );
		}
		
		// Give the player back their perks
		for ( i=0; i<self.laststand_perks.size; i++ )
		{
			if ( self HasPerk( self.laststand_perks[i] ) )
			{
				continue;
			}
			if( i == lost_perk_index )
			{
				continue;
			}
			
			maps\_zombiemode_perks::give_perk( self.laststand_perks[i] );
		}
	}
}

remote_revive_watch()
{
	self endon( "death" );
	self endon( "player_revived" );

	self waittill( "remote_revive", reviver );

	self maps\_laststand::remote_revive( reviver );
}

remove_deadshot_bottle()
{
	wait( 0.05 );

	if ( isdefined( self.lastActiveWeapon ) && self.lastActiveWeapon == "zombie_perk_bottle_deadshot" ) 
	{
		self.lastActiveWeapon = "none";
	}
}

take_additionalprimaryweapon()
{
	weapon_to_take = undefined;

	if ( is_true( self._retain_perks ) )
	{
		return weapon_to_take;
	}

	primary_weapons_that_can_be_taken = [];

	primaryWeapons = self GetWeaponsListPrimaries();
	for ( i = 0; i < primaryWeapons.size; i++ )
	{
		if ( maps\_zombiemode_weapons::is_weapon_included( primaryWeapons[i] ) || maps\_zombiemode_weapons::is_weapon_upgraded( primaryWeapons[i] ) )
		{
			primary_weapons_that_can_be_taken[primary_weapons_that_can_be_taken.size] = primaryWeapons[i];
		}
	}

	if ( primary_weapons_that_can_be_taken.size >= 3 )
	{
		weapon_to_take = primary_weapons_that_can_be_taken[primary_weapons_that_can_be_taken.size - 1];
		if ( weapon_to_take == self GetCurrentWeapon() )
		{
			self SwitchToWeapon( primary_weapons_that_can_be_taken[0] );
		}
		self TakeWeapon( weapon_to_take );
	}

	return weapon_to_take;
}

player_laststand( eInflictor, attacker, iDamage, sMeansOfDeath, sWeapon, vDir, sHitLoc, psOffsetTime, deathAnimDuration )
{
	// Grab the perks, we'll give them back to the player if he's revived
	//self.laststand_perks = maps\_zombiekmode_deathcard::deathcard_save_perks( self );

 	/#if ( self HasPerk( "specialty_additionalprimaryweapon" ) )
 	{
 		self.weapon_taken_by_losing_specialty_additionalprimaryweapon = self take_additionalprimaryweapon();
 	}#/

	//AYERS: Working on Laststand Audio
	/*
	players = get_players();
	if( players.size >= 2 )
	{
	    self clientnotify( "lststnd" );
	}
	*/
	
		//if ( IsDefined( level.deathcard_laststand_func ) )
	//{
	//	self [[ level.deathcard_laststand_func ]]();
	//}
	self clear_is_drinking();

	self thread remove_deadshot_bottle();
	
	self thread remote_revive_watch();
	
	self maps\_zombiemode_score::player_downed_penalty();
	
	// Turns out we need to do this after all, but we don't want to change _laststand.gsc postship, so I'm doing it here manually instead
	self DisableOffhandWeapons();

	self thread last_stand_grenade_save_and_return();
	
	if( sMeansOfDeath != "MOD_SUICIDE" && sMeansOfDeath != "MOD_FALLING" )
	{
	    self maps\_zombiemode_audio::create_and_play_dialog( "general", "revive_down" );
	}
	
	bbPrint( "zombie_playerdeaths: round %d playername %s deathtype downed x %f y %f z %f", level.round_number, self.playername, self.origin );
	
	if( IsDefined( level._zombie_minigun_powerup_last_stand_func ) )
	{
		self thread [[level._zombie_minigun_powerup_last_stand_func]]();
	}
	
	if( IsDefined( level._zombie_tesla_powerup_last_stand_func ) )
	{
		self thread [[level._zombie_tesla_powerup_last_stand_func]]();
	}

	if( IsDefined( self.intermission ) && self.intermission )
	{
		//maps\_zombiemode_challenges::doMissionCallback( "playerDied", self );

		bbPrint( "zombie_playerdeaths: round %d playername %s deathtype died x %f y %f z %f", level.round_number, self.playername, self.origin );

		level waittill( "forever" );
	}
}


failsafe_revive_give_back_weapons()
{
	for ( i = 0; i < 10; i++ )
	{
		wait( 0.05 );
		
		if ( !isdefined( self.reviveProgressBar ) )
		{
			continue;
		}

		players = get_players();
		for ( playerIndex = 0; playerIndex < players.size; playerIndex++ )
		{
			revivee = players[playerIndex];

			if ( self maps\_laststand::is_reviving( revivee ) )
			{
				// don't clean up revive stuff if he is reviving someone else
				continue;
			}
		}

		// he's not reviving anyone but he still has revive stuff up, clean it all up
/#
iprintlnbold( "FAILSAFE CLEANING UP REVIVE HUD AND GUN" );
#/
		// pass in "none" since we have no idea what the weapon they should be showing is
		self maps\_laststand::revive_give_back_weapons( "none" );

		if ( isdefined( self.reviveProgressBar ) )
		{
			self.reviveProgressBar maps\_hud_util::destroyElem();
		}

		if ( isdefined( self.reviveTextHud ) )
		{
			self.reviveTextHud destroy();
		}

		return;
	}
}


spawnSpectator()
{
	self endon( "disconnect" ); 
	self endon( "spawned_spectator" ); 
	self notify( "spawned" ); 
	self notify( "end_respawn" );

	if( level.intermission )
	{
		return;
	}

	if( IsDefined( level.no_spectator ) && level.no_spectator )
	{
		wait( 3 );
		ExitLevel();
	}

	// The check_for_level_end looks for this
	self.is_zombie = true;

	//failsafe against losing viewarms due to the thread returning them getting an endon from "zombified"
	players = get_players();
	for ( i = 0; i < players.size; i++ )
	{
		if ( self != players[i] )
		{
			players[i] thread failsafe_revive_give_back_weapons();
		}
	}

	// Remove all reviving abilities
	self notify ( "zombified" );

	if( IsDefined( self.revivetrigger ) )
	{
		self.revivetrigger delete();
		self.revivetrigger = undefined;
	}

	self.zombification_time = GetTime(); //set time when player died

	resetTimeout(); 

	// Stop shellshock and rumble
	self StopShellshock(); 
	self StopRumble( "damage_heavy" ); 

	self.sessionstate = "spectator"; 
	self.spectatorclient = -1;

	self remove_from_spectate_list();

	self.maxhealth = self.health;
	self.shellshocked = false; 
	self.inWater = false; 
	self.friendlydamage = undefined; 
	self.hasSpawned = true; 
	self.spawnTime = GetTime(); 
	self.afk = false; 

	println( "*************************Zombie Spectator***" );
	self detachAll();

	self setSpectatePermissions( true );
	self thread spectator_thread();

	self Spawn( self.origin, self.angles );
	self notify( "spawned_spectator" );
}

setSpectatePermissions( isOn )
{
	self AllowSpectateTeam( "allies", isOn );
	self AllowSpectateTeam( "axis", false );
	self AllowSpectateTeam( "freelook", false );
	self AllowSpectateTeam( "none", false );	
}

spectator_thread()
{
	self endon( "disconnect" ); 
	self endon( "spawned_player" );

/*	we are not currently supporting the shared screen tech
	if( IsSplitScreen() )
	{
		last_alive = undefined;
		players = get_players();

		for( i = 0; i < players.size; i++ )
		{
			if( !players[i].is_zombie )
			{
				last_alive = players[i];
			}
		}

		share_screen( last_alive, true );

		return;
	}
*/

//	self thread spectator_toggle_3rd_person();
}

spectator_toggle_3rd_person()
{
	self endon( "disconnect" ); 
	self endon( "spawned_player" );

	third_person = true;
	self set_third_person( true );
	//	self NotifyOnCommand( "toggle_3rd_person", "weapnext" );

	//	while( 1 )
	//	{
	//		self waittill( "toggle_3rd_person" );
	//
	//		if( third_person )
	//		{
	//			third_person = false;
	//			self set_third_person( false );
	//			wait( 0.5 );
	//		}
	//		else
	//		{
	//			third_person = true;
	//			self set_third_person( true );
	//			wait( 0.5 );
	//		}
	//	}
}


set_third_person( value )
{
	if( value )
	{
		self SetClientDvars( "cg_thirdPerson", "1",
			"cg_fov", "40",
			"cg_thirdPersonAngle", "354" );

		self setDepthOfField( 0, 128, 512, 4000, 6, 1.8 );
	}
	else
	{
		self SetClientDvars( "cg_thirdPerson", "0",
			"cg_fov", "65",
			"cg_thirdPersonAngle", "0" );

		self setDepthOfField( 0, 0, 512, 4000, 4, 0 );
	}
}

last_stand_revive()
{
	level endon( "between_round_over" );

	players = getplayers();

	for ( i = 0; i < players.size; i++ )
	{
		if ( players[i] maps\_laststand::player_is_in_laststand() && players[i].revivetrigger.beingRevived == 0 )
		{
			players[i] maps\_laststand::auto_revive();
		}
	}
}

// ww: arrange the last stand pistols so when it come time to choose which one they are inited
last_stand_pistol_rank_init()
{
	level.pistol_values = [];
	
	flag_wait( "_start_zm_pistol_rank" );
	
	if( flag( "solo_game" ) ) 
	{
		// ww: in a solo game the ranking of the pistols is a bit different based on the upgraded 1911 swap
		// any pistol ranked 4 or lower will be ignored and the player will be given the upgraded 1911
		level.pistol_values[ level.pistol_values.size ] = "m1911_zm";
		level.pistol_values[ level.pistol_values.size ] = "cz75_zm";
		level.pistol_values[ level.pistol_values.size ] = "cz75dw_zm";
		level.pistol_values[ level.pistol_values.size ] = "python_zm";
		level.pistol_values[ level.pistol_values.size ] = "python_upgraded_zm"; // ww: this is spot 4, anything scoring lower than this should be replaced
		level.pistol_values[ level.pistol_values.size ] = "cz75_upgraded_zm";
		level.pistol_values[ level.pistol_values.size ] = "cz75dw_upgraded_zm";
		level.pistol_values[ level.pistol_values.size ] = "m1911_upgraded_zm";
		level.pistol_values[ level.pistol_values.size ] = "ray_gun_zm";
		level.pistol_values[ level.pistol_values.size ] = "freezegun_zm";
		level.pistol_values[ level.pistol_values.size ] = "ray_gun_upgraded_zm";
		level.pistol_values[ level.pistol_values.size ] = "freezegun_upgraded_zm";
		level.pistol_values[ level.pistol_values.size ] = "microwavegundw_zm";
		level.pistol_values[ level.pistol_values.size ] = "microwavegundw_upgraded_zm";
	}
	else
	{
		level.pistol_values[ level.pistol_values.size ] = "m1911_zm";
		level.pistol_values[ level.pistol_values.size ] = "cz75_zm";
		level.pistol_values[ level.pistol_values.size ] = "cz75dw_zm";
		level.pistol_values[ level.pistol_values.size ] = "python_zm";
		level.pistol_values[ level.pistol_values.size ] = "python_upgraded_zm";
		level.pistol_values[ level.pistol_values.size ] = "cz75_upgraded_zm";
		level.pistol_values[ level.pistol_values.size ] = "cz75dw_upgraded_zm";
		level.pistol_values[ level.pistol_values.size ] = "m1911_upgraded_zm";
		level.pistol_values[ level.pistol_values.size ] = "ray_gun_zm";
		level.pistol_values[ level.pistol_values.size ] = "freezegun_zm";
		level.pistol_values[ level.pistol_values.size ] = "ray_gun_upgraded_zm";
		level.pistol_values[ level.pistol_values.size ] = "freezegun_upgraded_zm";
		level.pistol_values[ level.pistol_values.size ] = "microwavegundw_zm";
		level.pistol_values[ level.pistol_values.size ] = "microwavegundw_upgraded_zm";
	}

}

// ww: changing the _laststand scripts to this one so we interfere with SP less
last_stand_pistol_swap()
{
	if ( self has_powerup_weapon() )
	{
		// this will force the laststand module to switch us to any primary weapon, since we will no longer have this after revive
		self.lastActiveWeapon = "none";
	}

	if ( !self HasWeapon( self.laststandpistol ) )
	{
		self GiveWeapon( self.laststandpistol );
	}
	ammoclip = WeaponClipSize( self.laststandpistol );
	doubleclip = ammoclip * 2;
	
	if( is_true( self._special_solo_pistol_swap ) || (self.laststandpistol == "m1911_upgraded_zm" && !self.hadpistol) )
	{
		self._special_solo_pistol_swap = 0;
		self.hadpistol = false;
		self SetWeaponAmmoStock( self.laststandpistol, doubleclip );
	}
	else if( flag("solo_game") && self.laststandpistol == "m1911_upgraded_zm")
	{
		self SetWeaponAmmoStock( self.laststandpistol, doubleclip );
	}
	else if ( self.laststandpistol == "m1911_zm" )
	{
		self SetWeaponAmmoStock( self.laststandpistol, doubleclip );
	}
	else if ( self.laststandpistol == "ray_gun_zm" || self.laststandpistol == "ray_gun_upgraded_zm" )
	{
		if ( self.stored_weapon_info[ self.laststandpistol ].total_amt >= ammoclip )
		{
			self SetWeaponAmmoClip( self.laststandpistol, ammoclip );
			self.stored_weapon_info[ self.laststandpistol ].given_amt = ammoclip;
		}
		else
		{
			self SetWeaponAmmoClip( self.laststandpistol, self.stored_weapon_info[ self.laststandpistol ].total_amt );
			self.stored_weapon_info[ self.laststandpistol ].given_amt = self.stored_weapon_info[ self.laststandpistol ].total_amt;
		}
		self SetWeaponAmmoStock( self.laststandpistol, 0 );
	}
	else
	{
		if ( self.stored_weapon_info[ self.laststandpistol ].stock_amt >= doubleclip )
		{
			self SetWeaponAmmoStock( self.laststandpistol, doubleclip );
			self.stored_weapon_info[ self.laststandpistol ].given_amt = doubleclip + self.stored_weapon_info[ self.laststandpistol ].clip_amt + self.stored_weapon_info[ self.laststandpistol ].left_clip_amt;
		}
		else
		{
			self SetWeaponAmmoStock( self.laststandpistol, self.stored_weapon_info[ self.laststandpistol ].stock_amt );
			self.stored_weapon_info[ self.laststandpistol ].given_amt = self.stored_weapon_info[ self.laststandpistol ].total_amt;
		}
	}
	
	self SwitchToWeapon( self.laststandpistol );
}

// ww: make sure the player has the best pistol when they go in to last stand
last_stand_best_pistol()
{
	pistol_array = [];

	current_weapons = self GetWeaponsListPrimaries();
	
	for( i = 0; i < current_weapons.size; i++ )
	{
		// make sure the weapon is a pistol
		if( WeaponClass( current_weapons[i] ) == "pistol" )
		{
			if (  (current_weapons[i] != "m1911_zm" && !flag("solo_game") )  || (!flag("solo_game") && current_weapons[i] != "m1911_upgraded_zm" ))
			{
				
				if ( self GetAmmoCount( current_weapons[i] ) <= 0 )
				{
					continue;
				}
			}

			pistol_array_index = pistol_array.size; // set up the spot in the array 
			pistol_array[ pistol_array_index ] = SpawnStruct(); // struct to store info on
			
			pistol_array[ pistol_array_index ].gun = current_weapons[i];
			pistol_array[ pistol_array_index ].value = 0; // add a value in case a new weapon is introduced that hasn't been set up in level.pistol_values
			
			// compare the current weapon to the level.pistol_values to see what the value is
			for( j = 0; j < level.pistol_values.size; j++ )
			{
				if( level.pistol_values[j] == current_weapons[i] )
				{
					pistol_array[ pistol_array_index ].value = j;
					break;
				}
			}
		}
	}
	
	self.laststandpistol = last_stand_compare_pistols( pistol_array );
}

// ww: compares the array passed in for the highest valued pistol
last_stand_compare_pistols( struct_array )
{
	if( !IsArray( struct_array ) || struct_array.size <= 0 )
	{
		self.hadpistol = false;
		
		//array will be empty if the pistol had no ammo...so lets see if the player had the pistol
		if(isDefined(self.stored_weapon_info))
		{
			stored_weapon_info = GetArrayKeys( self.stored_weapon_info );
			for( j = 0; j < stored_weapon_info.size; j++ )
			{
				if( stored_weapon_info[ j ] == level.laststandpistol)
				{
					self.hadpistol = true;
				}
			}
		}
				
		return level.laststandpistol; // nothing in the array then give the level last stand pistol
	}
	
	highest_score_pistol = struct_array[0]; // first time through give the first one to the highest score

	for( i = 1; i < struct_array.size; i++ )
	{
		if( struct_array[i].value > highest_score_pistol.value )
		{
			highest_score_pistol = struct_array[i];
		}
	}

	if( flag( "solo_game" ) )
	{
		self._special_solo_pistol_swap = 0; // ww: this way the weapon knows to pack texture when given
		if( highest_score_pistol.value <= 4 )
		{
			self.hadpistol = false;
			self._special_solo_pistol_swap = 1;
			return level.laststandpistol; // ww: if it scores too low the player gets the 1911 upgraded
		}
		else
		{
			return highest_score_pistol.gun; // ww: gun is high in ranking and won't be replaced
		}
	}
	else // ww: happens when not in solo
	{
		return highest_score_pistol.gun;
	}

}

// ww: override function for saving player pistol ammo count
last_stand_save_pistol_ammo()
{
	weapon_inventory = self GetWeaponsList();
	self.stored_weapon_info = [];

	for( i = 0; i < weapon_inventory.size; i++ )
	{
		weapon = weapon_inventory[i];

		if ( WeaponClass( weapon ) == "pistol" ) 
		{
			self.stored_weapon_info[ weapon ] = SpawnStruct();
			self.stored_weapon_info[ weapon ].clip_amt = self GetWeaponAmmoClip( weapon );
			self.stored_weapon_info[ weapon ].left_clip_amt = 0;
			dual_wield_name = WeaponDualWieldWeaponName( weapon );
			if ( "none" != dual_wield_name )
			{
				self.stored_weapon_info[ weapon ].left_clip_amt = self GetWeaponAmmoClip( dual_wield_name );
			}
			self.stored_weapon_info[ weapon ].stock_amt = self GetWeaponAmmoStock( weapon );
			self.stored_weapon_info[ weapon ].total_amt = self.stored_weapon_info[ weapon ].clip_amt + self.stored_weapon_info[ weapon ].left_clip_amt + self.stored_weapon_info[ weapon ].stock_amt;
			self.stored_weapon_info[ weapon ].given_amt = 0;
		}
	}
	
	self last_stand_best_pistol();
}

// ww: override to restore the player's pistol ammo after being picked up
last_stand_restore_pistol_ammo()
{
	self.weapon_taken_by_losing_specialty_additionalprimaryweapon = undefined;

	if( !IsDefined( self.stored_weapon_info ) )
	{
		return;
	}
	
	weapon_inventory = self GetWeaponsList();
	weapon_to_restore = GetArrayKeys( self.stored_weapon_info );
	
	for( i = 0; i < weapon_inventory.size; i++ )
	{
		weapon = weapon_inventory[i];

		if ( weapon != self.laststandpistol )
		{
			continue;
		}

		for( j = 0; j < weapon_to_restore.size; j++ )
		{
			check_weapon = weapon_to_restore[j];
			
			if( weapon == check_weapon )
			{
				dual_wield_name = WeaponDualWieldWeaponName( weapon_to_restore[j] );
				if ( weapon != "m1911_zm" )
				{
					last_clip = self GetWeaponAmmoClip( weapon );
					last_left_clip = 0;
					if ( "none" != dual_wield_name )
					{
						last_left_clip = self GetWeaponAmmoClip( dual_wield_name );
					}
					last_stock = self GetWeaponAmmoStock( weapon );
					last_total = last_clip + last_left_clip + last_stock;

					used_amt = self.stored_weapon_info[ weapon ].given_amt - last_total;

					if ( used_amt >= self.stored_weapon_info[ weapon ].stock_amt )
					{
						used_amt -= self.stored_weapon_info[ weapon ].stock_amt;
						self.stored_weapon_info[ weapon ].stock_amt = 0;

						self.stored_weapon_info[ weapon ].clip_amt -= used_amt;
						if ( self.stored_weapon_info[ weapon ].clip_amt < 0 )
						{
							self.stored_weapon_info[ weapon ].clip_amt = 0;
						}
					}
					else 
					{
						new_stock_amt = self.stored_weapon_info[ weapon ].stock_amt - used_amt;
						if ( new_stock_amt < self.stored_weapon_info[ weapon ].stock_amt )
						{
							self.stored_weapon_info[ weapon ].stock_amt = new_stock_amt;
						}
					}
				}

				self SetWeaponAmmoClip( weapon_to_restore[j], self.stored_weapon_info[ weapon_to_restore[j] ].clip_amt );
				if ( "none" != dual_wield_name )
				{
					self SetWeaponAmmoClip( dual_wield_name , self.stored_weapon_info[ weapon_to_restore[j] ].left_clip_amt );
				}
				self SetWeaponAmmoStock( weapon_to_restore[j], self.stored_weapon_info[ weapon_to_restore[j] ].stock_amt );
				break;
			}
		}
	}
}

// ww: changes the last stand pistol to the upgraded 1911s if it is solo
zombiemode_solo_last_stand_pistol()
{
	level.laststandpistol = "m1911_upgraded_zm";
}

// ww: zeros out the player's grenades until they revive
last_stand_grenade_save_and_return()
{
	self endon( "death" );
	
	lethal_nade_amt = 0;
	has_lethal_nade = false;
	tactical_nade_amt = 0;
	has_tactical_nade = false;
	
	// figure out which nades this player has
	weapons_on_player = self GetWeaponsList();
	for ( i = 0; i < weapons_on_player.size; i++ )
	{
		if ( self is_player_lethal_grenade( weapons_on_player[i] ) )
		{
			has_lethal_nade = true;
			lethal_nade_amt = self GetWeaponAmmoClip( self get_player_lethal_grenade() );
			self SetWeaponAmmoClip( self get_player_lethal_grenade(), 0 );
			self TakeWeapon( self get_player_lethal_grenade() );
		}
		else if ( self is_player_tactical_grenade( weapons_on_player[i] ) )
		{
			has_tactical_nade = true;
			tactical_nade_amt = self GetWeaponAmmoClip( self get_player_tactical_grenade() );
			self SetWeaponAmmoClip( self get_player_tactical_grenade(), 0 );
			self TakeWeapon( self get_player_tactical_grenade() );
		}
	}
	
	self waittill( "player_revived" );
	
	if ( has_lethal_nade )
	{
		self GiveWeapon( self get_player_lethal_grenade() );
		self SetWeaponAmmoClip( self get_player_lethal_grenade(), lethal_nade_amt );
	}
	
	if ( has_tactical_nade )
	{
		self GiveWeapon( self get_player_tactical_grenade() );
		self SetWeaponAmmoClip( self get_player_tactical_grenade(), tactical_nade_amt );
	}
}

spectators_respawn()
{
	level endon( "between_round_over" );

	if( !IsDefined( level.zombie_vars["spectators_respawn"] ) || !level.zombie_vars["spectators_respawn"] )
	{
		return;
	}

	if( !IsDefined( level.custom_spawnPlayer ) )
	{
		// Custom spawn call for when they respawn from spectator
		level.custom_spawnPlayer = ::spectator_respawn;
	}

	while( 1 )
	{
		players = get_players();
		for( i = 0; i < players.size; i++ )
		{
			if( players[i].sessionstate == "spectator" )
			{
				players[i] [[level.spawnPlayer]]();
				if (isDefined(level.script) && level.round_number > 6 && players[i].score < 1500)
				{
					players[i].old_score = players[i].score;
					players[i].score = 1500;
					players[i] maps\_zombiemode_score::set_player_score_hud();
				}
			}
		}

		wait( 1 );
	}
}

spectator_respawn()
{
	println( "*************************Respawn Spectator***" );
	assert( IsDefined( self.spectator_respawn ) );

	origin = self.spectator_respawn.origin;
	angles = self.spectator_respawn.angles;

	self setSpectatePermissions( false );

	new_origin = undefined;
	
	if ( isdefined( level.check_valid_spawn_override ) )
	{
		new_origin = [[ level.check_valid_spawn_override ]]( self );
	}

	if ( !isdefined( new_origin ) )
	{
		new_origin = check_for_valid_spawn_near_team( self );
	}

	if( IsDefined( new_origin ) )
	{
		self Spawn( new_origin, angles );
	}
	else
	{
		self Spawn( origin, angles );
	}


/*	we are not currently supporting the shared screen tech
	if( IsSplitScreen() )
	{
		last_alive = undefined;
		players = get_players();

		for( i = 0; i < players.size; i++ )
		{
			if( !players[i].is_zombie )
			{
				last_alive = players[i];
			}
		}

		share_screen( last_alive, false );
	}
*/

	if ( IsDefined( self get_player_placeable_mine() ) )
	{
		self TakeWeapon( self get_player_placeable_mine() );
		self set_player_placeable_mine( undefined );
	}

	self maps\_zombiemode_equipment::equipment_take();

	self.is_burning = undefined;
	self.abilities = [];

	// The check_for_level_end looks for this
	self.is_zombie = false;
	self.ignoreme = false;

	setClientSysState("lsm", "0", self);	// Notify client last stand ended.
	self RevivePlayer();

	self notify( "spawned_player" );

	if(IsDefined(level._zombiemode_post_respawn_callback))
	{
		self thread [[level._zombiemode_post_respawn_callback]]();
	}

	// Penalize the player when we respawn, since he 'died'
	self maps\_zombiemode_score::player_reduce_points( "died" );
	
	//DCS: make bowie & claymore trigger available again.
	bowie_triggers = GetEntArray( "bowie_upgrade", "targetname" );
	// ww: player needs to reset trigger knowledge without claiming full ownership
	self._bowie_zm_equipped = undefined;
	players = get_players();
	for( i = 0; i < bowie_triggers.size; i++ )
	{
		bowie_triggers[i] SetVisibleToAll();
		// check the player to see if he has the bowie, if they do trigger goes invisible
		for( j = 0; j < players.size; j++ )
		{
			if( IsDefined( players[j]._bowie_zm_equipped ) && players[j]._bowie_zm_equipped == 1 )
			{
				bowie_triggers[i] SetInvisibleToPlayer( players[j] );
			}
		}
	}
	
	sickle_triggers = GetEntArray( "sickle_upgrade", "targetname" );
	// ww: player needs to reset trigger knowledge without claiming full ownership
	self._sickle_zm_equipped = undefined;
	players = get_players();
	for( i = 0; i < sickle_triggers.size; i++ )
	{
		sickle_triggers[i] SetVisibleToAll();
		// check the player to see if he has the sickle, if they do trigger goes invisible
		for( j = 0; j < players.size; j++ )
		{
			if( IsDefined( players[j]._sickle_zm_equipped ) && players[j]._sickle_zm_equipped == 1 )
			{
				sickle_triggers[i] SetInvisibleToPlayer( players[j] );
			}
		}
	}

	// ww: inside _zombiemode_claymore the claymore triggers are fixed for players who haven't bought them
	// to see them after someone respawns from bleedout
	// it isn't the best way to do it but it is late in the project and probably better if i don't modify it
	// unless a bug comes through on it
	claymore_triggers = getentarray("claymore_purchase","targetname");
	for(i = 0; i < claymore_triggers.size; i++)
	{
		claymore_triggers[i] SetVisibleToPlayer(self);
		claymore_triggers[i].claymores_triggered = false;		
	}	

	self thread player_zombie_breadcrumb();

	return true;
}

check_for_valid_spawn_near_team( revivee )
{

	players = get_players();
	spawn_points = getstructarray("player_respawn_point", "targetname");
	closest_group = undefined;
	closest_distance = 100000000;
	backup_group = undefined;
	backup_distance = 100000000;

	if( spawn_points.size == 0 )
		return undefined;

	// Look for the closest group that is within the specified ideal distances
	//	If we can't find one within a valid area, use the closest unlocked group.
	for( i = 0; i < players.size; i++ )
	{
		if( is_player_valid( players[i] ) )
		{
			for( j = 0 ; j < spawn_points.size; j++ )
			{
				if( isdefined(spawn_points[i].script_int) )
					ideal_distance = spawn_points[i].script_int;
				else
					ideal_distance = 1000;

				if ( spawn_points[j].locked == false )
				{
					distance = DistanceSquared( players[i].origin, spawn_points[j].origin );
					if( distance < ( ideal_distance * ideal_distance ) )
					{
						if ( distance < closest_distance )
						{
							closest_distance = distance;
							closest_group = j;
						}
					}
					else
					{
						if ( distance < backup_distance )
						{
							backup_group = j;
							backup_distance = distance;
						}
					}
				}
			}
		}
		//	If we don't have a closest_group, let's use the backup
		if ( !IsDefined( closest_group ) )
		{
			closest_group = backup_group;
		}

		if ( IsDefined( closest_group ) )
		{
			spawn_array = getstructarray( spawn_points[closest_group].target, "targetname" );

			for( k = 0; k < spawn_array.size; k++ )
			{
				if( spawn_array[k].script_int == (revivee.entity_num + 1) )
				{
					return spawn_array[k].origin; 
				}
			}	

			return spawn_array[0].origin;
		}
	}

	return undefined;

}


get_players_on_team(exclude)
{

	teammates = [];

	players = get_players();
	for(i=0;i<players.size;i++)
	{		
		//check to see if other players on your team are alive and not waiting to be revived
		if(players[i].spawn_side == self.spawn_side && !isDefined(players[i].revivetrigger) && players[i] != exclude )
		{
			teammates[teammates.size] = players[i];
		}
	}

	return teammates;
}



get_safe_breadcrumb_pos( player )
{
	players = get_players();
	valid_players = [];

	min_dist = 150 * 150;
	for( i = 0; i < players.size; i++ )
	{
		if( !is_player_valid( players[i] ) )
		{
			continue;
		}

		valid_players[valid_players.size] = players[i];
	}

	for( i = 0; i < valid_players.size; i++ )
	{
		count = 0;
		for( q = 1; q < player.zombie_breadcrumbs.size; q++ )
		{
			if( DistanceSquared( player.zombie_breadcrumbs[q], valid_players[i].origin ) < min_dist )
			{
				continue;
			}
			
			count++;
			if( count == valid_players.size )
			{
				return player.zombie_breadcrumbs[q];
			}
		}
	}

	return undefined;
}

default_max_zombie_func( max_num )
{
	max = max_num;

	if ( level.first_round && level.round_number == 1 )
	{
		max = int( max_num * 0.25 );	
	}
	else if (level.round_number < 3)
	{
		max = int( max_num * 0.3 );
	}
	else if (level.round_number < 4)
	{
		max = int( max_num * 0.5 );
	}
	else if (level.round_number < 5)
	{
		max = int( max_num * 0.7 );
	}
	else if (level.round_number < 6)
	{
		max = int( max_num * 0.9 );
	}
	
	return max;
}

round_spawning()
{
	level endon( "intermission" );
	level endon( "end_of_round" );
	level endon( "restart_round" );
/#
	level endon( "kill_round" );
#/

	if( level.intermission )
	{
		return;
	}

	if( level.enemy_spawns.size < 1 )
	{
		ASSERTMSG( "No active spawners in the map.  Check to see if the zone is active and if it's pointing to spawners." ); 
		return; 
	}

/#
	if ( GetDvarInt( #"zombie_cheat" ) == 2 || GetDvarInt( #"zombie_cheat" ) >= 4 ) 
	{
		return;
	}
#/

	ai_calculate_health( level.round_number ); 

	count = 0; 

	//CODER MOD: TOMMY K
	players = get_players();
	for( i = 0; i < players.size; i++ )
	{
		players[i].zombification_time = 0;
	}

	max = level.zombie_vars["zombie_max_ai"];

	multiplier = level.round_number / 5;
	if( multiplier < 1 )
	{
		multiplier = 1;
	}

	// After round 10, exponentially have more AI attack the player
	if( level.round_number >= 10 )
	{
		multiplier *= level.round_number * 0.15;
	}

	player_num = get_players().size;

	if( player_num == 1 )
	{
		max += int( ( 0.5 * level.zombie_vars["zombie_ai_per_player"] ) * multiplier ); 
	}
	else
	{
		max += int( ( ( player_num - 1 ) * level.zombie_vars["zombie_ai_per_player"] ) * multiplier ); 
	}

	if( !isDefined( level.max_zombie_func ) )
	{
		level.max_zombie_func = ::default_max_zombie_func;
	}

	// Now set the total for the new round, except when it's already been set by the
	//	kill counter.
	if ( !(IsDefined( level.kill_counter_hud ) && level.zombie_total > 0) )
	{
		level.zombie_total = [[ level.max_zombie_func ]]( max );
	}

	if ( IsDefined( level.zombie_total_set_func ) )
	{
		level thread [[ level.zombie_total_set_func ]]();
	}

	if ( level.round_number < 10 )
	{
		level thread zombie_speed_up();
	}

	mixed_spawns = 0;	// Number of mixed spawns this round.  Currently means number of dogs in a mixed round

	// DEBUG HACK:	
	//max = 1;
	old_spawn = undefined;
//	while( level.zombie_total > 0 )
	while( 1 )
	{
		while( get_enemy_count() >= level.zombie_ai_limit || level.zombie_total <= 0 )
		{
			wait( 0.1 );
		}

		// added ability to pause zombie spawning
		if ( !flag("spawn_zombies" ) )
		{
			flag_wait( "spawn_zombies" );
		}

		spawn_point = level.enemy_spawns[RandomInt( level.enemy_spawns.size )]; 

		if( !IsDefined( old_spawn ) )
		{
				old_spawn = spawn_point;
		}
		else if( Spawn_point == old_spawn )
		{
				spawn_point = level.enemy_spawns[RandomInt( level.enemy_spawns.size )]; 
		}
		old_spawn = spawn_point;

	//	iPrintLn(spawn_point.targetname + " " + level.zombie_vars["zombie_spawn_delay"]);

		// MM Mix in dog spawns...
		if ( IsDefined( level.mixed_rounds_enabled ) && level.mixed_rounds_enabled == 1 && isdefined( level.game_started ) && level.game_started == 1 )
		{
			spawn_dog = false;
			if ( level.round_number > 30 )
			{
				if ( RandomInt(100) < 3 )
				{
					spawn_dog = true;
				}
			}
			else if ( level.round_number > 25 && mixed_spawns < 3 )
			{
				if ( RandomInt(100) < 2 )
				{
					spawn_dog = true;
				}
			}
			else if ( level.round_number > 20 && mixed_spawns < 2 )
			{
				if ( RandomInt(100) < 2 )
				{
					spawn_dog = true;
				}
			}
			else if ( level.round_number > 15 && mixed_spawns < 1 )
			{
				if ( RandomInt(100) < 1 )
				{
					spawn_dog = true;
				}
			}
			
			if ( spawn_dog )
			{
				keys = GetArrayKeys( level.zones );
				for ( i=0; i<keys.size; i++ )
				{
					if ( level.zones[ keys[i] ].is_occupied )
					{
						akeys = GetArrayKeys( level.zones[ keys[i] ].adjacent_zones );
						for ( k=0; k<akeys.size; k++ )
						{
							if ( level.zones[ akeys[k] ].is_active &&
								 !level.zones[ akeys[k] ].is_occupied &&
								 level.zones[ akeys[k] ].dog_locations.size > 0 )
							{
								maps\_zombiemode_ai_dogs::special_dog_spawn( undefined, 1 );
								level.zombie_total--;
								wait_network_frame();
							}
						}
					}
				}
			}
		}

		ai = spawn_zombie( spawn_point ); 
		if( IsDefined( ai ) )
		{
			level.zombie_total--;
			ai thread round_spawn_failsafe();
			count++; 
		}

		wait( level.zombie_vars["zombie_spawn_delay"] ); 
		wait_network_frame();
	}
}

//
//	Make the last few zombies run
//
zombie_speed_up()
{
	if( level.round_number <= 3 )
	{
		return;
	}

	level endon( "intermission" );
	level endon( "end_of_round" );
	level endon( "restart_round" );
/#
	level endon( "kill_round" );
#/

	// Wait until we've finished spawning
	while ( level.zombie_total > 4 )
	{
		wait( 2.0 );
	}

	// Now wait for these guys to get whittled down
	num_zombies = get_enemy_count();
	while( num_zombies > 3 )
	{
		wait( 2.0 );

		num_zombies = get_enemy_count();
	}

	zombies = GetAiSpeciesArray( "axis", "all" );
	while( zombies.size > 0 )
	{
		if( zombies.size == 1 && zombies[0].has_legs == true )
		{
			if ( isdefined( level.zombie_speed_up ) )
			{
				zombies[0] thread [[ level.zombie_speed_up ]]();
				break;
			}
			else
			{
				var = randomintrange(1, 4);
				zombies[0] set_run_anim( "sprint" + var );                       
				zombies[0].run_combatanim = level.scr_anim[zombies[0].animname]["sprint" + var];
			}
		}
		wait(0.5);
		zombies = GetAiSpeciesArray( "axis", "all" );
	}
}

// TESTING: spawn one zombie at a time
round_spawning_test()
{
	while (true)
	{
		spawn_point = level.enemy_spawns[RandomInt( level.enemy_spawns.size )];	// grab a random spawner

		ai = spawn_zombie( spawn_point );
		ai waittill("death");

		wait 5;
	}
}


/////////////////////////////////////////////////////////

// round_text( text )
// {
// 	if( level.first_round )
// 	{
// 		intro = true;
// 	}
// 	else
// 	{
// 		intro = false;
// 	}
// 
// 	hud = create_simple_hud();
// 	hud.horzAlign = "center"; 
// 	hud.vertAlign = "middle";
// 	hud.alignX = "center"; 
// 	hud.alignY = "middle";
// 	hud.y = -100;
// 	hud.foreground = 1;
// 	hud.fontscale = 16.0;
// 	hud.alpha = 0; 
// 	hud.color = ( 1, 1, 1 );
// 
// 	hud SetText( text ); 
// 	hud FadeOverTime( 1.5 );
// 	hud.alpha = 1;
// 	wait( 1.5 );
// 
// 	if( intro )
// 	{
// 		wait( 1 );
// 		level notify( "intro_change_color" );
// 	}
// 
// 	hud FadeOverTime( 3 );
// 	//hud.color = ( 0.8, 0, 0 );
// 	hud.color = ( 0.21, 0, 0 );
// 	wait( 3 );
// 
// 	if( intro )
// 	{
// 		level waittill( "intro_hud_done" );
// 	}
// 
// 	hud FadeOverTime( 1.5 );
// 	hud.alpha = 0;
// 	wait( 1.5 ); 
// 	hud destroy();
// }


//	Allows the round to be paused.  Displays a countdown timer.
//
round_pause( delay )
{
	if ( !IsDefined( delay ) )
	{
		delay = 30;
	}

	level.countdown_hud = create_counter_hud();
	level.countdown_hud SetValue( delay );
	level.countdown_hud.color = ( 1, 1, 1 );
	level.countdown_hud.alpha = 1;
	level.countdown_hud FadeOverTime( 2.0 );
	wait( 2.0 );

	level.countdown_hud.color = ( 0.21, 0, 0 );
	level.countdown_hud FadeOverTime( 3.0 );
	wait(3);

	while (delay >= 1)
	{
		wait (1);
		delay--;
		level.countdown_hud SetValue( delay );
	}

	// Zero!  Play end sound
	players = GetPlayers();
	for (i=0; i<players.size; i++ )
	{
		players[i] playlocalsound( "zmb_perks_packa_ready" );
	}

	level.countdown_hud FadeOverTime( 1.0 );
	level.countdown_hud.color = (1,1,1);
	level.countdown_hud.alpha = 0;
	wait( 1.0 );

	level.countdown_hud destroy_hud();
	iprintln("Spawn Delay: " + level.zombie_vars["zombie_spawn_delay"]);
}


//	Zombie spawning
//
round_start()
{
	if ( IsDefined(level.round_prestart_func) )
	{
		[[ level.round_prestart_func ]]();
	}
	else
	{
		wait( 2 );
	}

	level.zombie_health = level.zombie_vars["zombie_health_start"]; 

	// so players get init'ed with grenades
	players = get_players();
	for (i = 0; i < players.size; i++)
	{
		players[i] giveweapon( players[i] get_player_lethal_grenade() );	
		players[i] setweaponammoclip( players[i] get_player_lethal_grenade(), 0);
		players[i] SetClientDvars( "ammoCounterHide", "0",
				"miniscoreboardhide", "0" );
		//players[i] thread maps\_zombiemode_ability::give_round1_abilities();
	}

	if( getDvarInt( #"scr_writeconfigstrings" ) == 1 )
	{
		wait(5);
		ExitLevel();
		return;
	}
//	if( isDefined(level.chests) && isDefined(level.chest_index) )
//	{
//		Objective_Add( 0, "active", "Mystery Box", level.chests[level.chest_index].chest_lid.origin, "minimap_icon_mystery_box" );
//	}

	if ( level.zombie_vars["game_start_delay"] > 0 )
	{
		round_pause( level.zombie_vars["game_start_delay"] );
	}

	flag_set( "begin_spawning" );
	
	//maps\_zombiemode_solo::init();

	level.chalk_hud1 = create_chalk_hud();
// 	if( level.round_number >= 1 && level.round_number <= 5 )
// 	{
// 		level.chalk_hud1 SetShader( "hud_chalk_" + level.round_number, 64, 64 );
// 	}
// 	else if ( level.round_number >= 5 && level.round_number <= 10 )
// 	{
// 		level.chalk_hud1 SetShader( "hud_chalk_5", 64, 64 );
// 	}
	level.chalk_hud2 = create_chalk_hud( 64 );

	//	level waittill( "introscreen_done" );

	if( !isDefined(level.round_spawn_func) )
	{
		level.round_spawn_func = ::round_spawning;
	}
/#
	if (GetDvarInt( #"zombie_rise_test") )
	{
		level.round_spawn_func = ::round_spawning_test;		// FOR TESTING, one zombie at a time, no round advancement
	}
#/

	if ( !isDefined(level.round_wait_func) )
	{
		level.round_wait_func = ::round_wait;
	}

	if ( !IsDefined(level.round_think_func) )
	{
		level.round_think_func = ::round_think;
	}

	if( level.mutators["mutator_fogMatch"] )
	{
		players = get_players();
		for( i = 0; i < players.size; i++ )
		{
			players[i] thread set_fog( 729.34, 971.99, 338.336, 398.623, 0.58, 0.60, 0.56, 3 );
		}
	}

	level thread [[ level.round_think_func ]]();
}


//
//
create_chalk_hud( x )
{
	if( !IsDefined( x ) )
	{
		x = 0;
	}

	hud = create_simple_hud();
	hud.alignX = "left"; 
	hud.alignY = "bottom";
	hud.horzAlign = "user_left"; 
	hud.vertAlign = "user_bottom";
	hud.color = ( 0.21, 0, 0 );
	hud.x = x; 
	hud.y = -4; 
	hud.alpha = 0;
	hud.fontscale = 32.0;

	hud SetShader( "hud_chalk_1", 64, 64 );

	return hud;
}


//
//
destroy_chalk_hud()
{
	if( isDefined( level.chalk_hud1 ) )
	{
		level.chalk_hud1 Destroy();
		level.chalk_hud1 = undefined;
	}

	if( isDefined( level.chalk_hud2 ) )
	{
		level.chalk_hud2 Destroy();
		level.chalk_hud2 = undefined;
	}
}


//
// Let's the players know that you need power to open these
play_door_dialog()
{
	level endon( "power_on" );
	self endon ("warning_dialog");
	timer = 0;

	while(1)
	{
		wait(0.05);
		players = get_players();
		for(i = 0; i < players.size; i++)
		{		
			dist = distancesquared(players[i].origin, self.origin );
			if(dist > 70*70)
			{
				timer =0;
				continue;
			}
			while(dist < 70*70 && timer < 3)
			{
				wait(0.5);
				timer++;
			}
			if(dist > 70*70 && timer >= 3)
			{
				self playsound("door_deny");
				
				players[i] maps\_zombiemode_audio::create_and_play_dialog( "general", "door_deny" );	
				wait(3);				
				self notify ("warning_dialog");
				//iprintlnbold("warning_given");
			}
		}
	}
}

wait_until_first_player()
{
	players = get_players();
	if( !IsDefined( players[0] ) )
	{
		level waittill( "first_player_ready" );
	}
}

//
//	Set the current round number hud display
chalk_one_up()
{
	huds = [];
	huds[0] = level.chalk_hud1;
	huds[1] = level.chalk_hud2;

	// Hud1 shader
	if( level.round_number >= 1 && level.round_number <= 5 )
	{
		huds[0] SetShader( "hud_chalk_" + level.round_number, 64, 64 );
	}
	else if ( level.round_number >= 5 && level.round_number <= 10 )
	{
		huds[0] SetShader( "hud_chalk_5", 64, 64 );
	}

	// Hud2 shader
	if( level.round_number > 5 && level.round_number <= 10 )
	{
		huds[1] SetShader( "hud_chalk_" + ( level.round_number - 5 ), 64, 64 );
	}

	// Display value
	if ( IsDefined( level.chalk_override ) )
	{
		huds[0] SetText( level.chalk_override );
		huds[1] SetText( " " );
	}
	else if( level.round_number <= 5 )
	{
		huds[1] SetText( " " );
	}
	else if( level.round_number > 10 )
	{
		huds[0].fontscale = 32;
		huds[0] SetValue( level.round_number );
		huds[1] SetText( " " );
	}

	if(!IsDefined(level.doground_nomusic))
	{
		level.doground_nomusic = 0;
	}
	if( level.first_round && level.round_number == 1)
	{
		intro = true;
		if( isdefined( level._custom_intro_vox ) )
		{
			level thread [[level._custom_intro_vox]]();
		}
		else
		{
			level thread play_level_start_vox_delayed();
		}
	}
	else
	{
		intro = false;
	}
	
	//Round Number Specific Lines
	if( level.round_number == 5 || level.round_number == 10 || level.round_number == 20 || level.round_number == 35 || level.round_number == 50 )
	{
	    players = getplayers();
	    rand = RandomIntRange(0,players.size);
	    players[rand] thread maps\_zombiemode_audio::create_and_play_dialog( "general", "round_" + level.round_number );
	}

	round = undefined;	
	if( intro )
	{
		// Create "ROUND" hud text
		round = create_simple_hud();
		round.alignX = "center"; 
		round.alignY = "bottom";
		round.horzAlign = "user_center"; 
		round.vertAlign = "user_bottom";
		round.fontscale = 16;
		round.color = ( 1, 1, 1 );
		round.x = 0;
		round.y = -265;
		round.alpha = 0;
		round SetText( &"ZOMBIE_ROUND" );

//		huds[0] FadeOverTime( 0.05 );
		huds[0].color = ( 1, 1, 1 );
		huds[0].alpha = 0;
		huds[0].horzAlign = "user_center";
		huds[0].x = -5;
		huds[0].y = -200;

		huds[1] SetText( " " );

		// Fade in white
		round FadeOverTime( 1 );
		round.alpha = 1;

		huds[0] FadeOverTime( 1 );
		huds[0].alpha = 1;

		wait( 1 );

		// Fade to red
		round FadeOverTime( 2 );
		round.color = ( 0.21, 0, 0 );

		huds[0] FadeOverTime( 2 );
		huds[0].color = ( 0.21, 0, 0 );
		wait(2);
	}
	else
	{
		for ( i=0; i<huds.size; i++ )
		{
			huds[i] FadeOverTime( 0.5 );
			huds[i].alpha = 0;
		}
		wait( 0.5 );
	}

// 	if( (level.round_number <= 5 || level.round_number >= 11) && IsDefined( level.chalk_hud2 ) )
// 	{
// 		huds[1] = undefined;
// 	}
// 	
	for ( i=0; i<huds.size; i++ )
	{
		huds[i] FadeOverTime( 2 );
		huds[i].alpha = 1;
	}

	if( intro )
	{
		wait( 3 );

		if( IsDefined( round ) )
		{
			round FadeOverTime( 1 );
			round.alpha = 0;
		}

		wait( 0.25 );

		level notify( "intro_hud_done" );
		huds[0] MoveOverTime( 1.75 );
		huds[0].horzAlign = "user_left";
		//		huds[0].x = 0;
		huds[0].y = -4;
		wait( 2 );

		round destroy_hud();
	}
	else
	{
		for ( i=0; i<huds.size; i++ )
		{
			huds[i].color = ( 1, 1, 1 );
		}
	}

	// Okay now wait just a bit to let the number set in
	if ( !intro )
	{
		wait( 2 ); 

		for ( i=0; i<huds.size; i++ )
		{
			huds[i] FadeOverTime( 1 );
			huds[i].color = ( 0.21, 0, 0 );
		}
	}
	
	ReportMTU(level.round_number);	// In network debug instrumented builds, causes network spike report to generate.

	// Remove any override set since we're done with it
	if ( IsDefined( level.chalk_override ) )
	{
		level.chalk_override = undefined;
	}
}


//	Flash the round display at the end of the round
//
chalk_round_over()
{
	huds = [];
	huds[huds.size] = level.chalk_hud1;
	huds[huds.size] = level.chalk_hud2;

	if( level.round_number <= 5 || level.round_number > 10 )
	{
		level.chalk_hud2 SetText( " " );
	}

	time = level.zombie_vars["zombie_between_round_time"];
	if ( time > 3 )
	{
		time = time - 2;	// add this deduction back in at the bottom
	}

	for( i = 0; i < huds.size; i++ )
	{
		if( IsDefined( huds[i] ) )
		{
			huds[i] FadeOverTime( time * 0.25 );
			huds[i].color = ( 1, 1, 1 );
		}
	}

	// Pulse
	fade_time = 0.5;
	steps =  ( time * 0.5 ) / fade_time;
	for( q = 0; q < steps; q++ )
	{
		for( i = 0; i < huds.size; i++ )
		{
			if( !IsDefined( huds[i] ) )
			{
				continue;
			}

			huds[i] FadeOverTime( fade_time );
			huds[i].alpha = 0;
		}

		wait( fade_time );

		for( i = 0; i < huds.size; i++ )
		{
			if( !IsDefined( huds[i] ) )
			{
				continue;
			}

			huds[i] FadeOverTime( fade_time );
			huds[i].alpha = 1;		
		}

		wait( fade_time );
	}

	for( i = 0; i < huds.size; i++ )
	{
		if( !IsDefined( huds[i] ) )
		{
			continue;
		}

		huds[i] FadeOverTime( time * 0.25 );
		//		huds[i].color = ( 0.8, 0, 0 );
		huds[i].color = ( 0.21, 0, 0 );
		huds[i].alpha = 0;
	}

	wait ( 2.0 );
}

round_think()
{
	round_number = getDvar( "round_number" );
	if( round_number == "" )
	{
		round_number = 100;
	}
	level.round_number = int(round_number);

	for(i = 0; i < level.round_number; i++) {
		if(level.zombie_vars["zombie_spawn_delay"] > .08) {
			level.zombie_vars["zombie_spawn_delay"] = level.zombie_vars["zombie_spawn_delay"] * .95;
		}			
		else if(level.zombie_vars["zombie_spawn_delay"] < .08) {
			level.zombie_vars["zombie_spawn_delay"] = .08;
		}
	}

	round_pause( getDvarInt( "round_start_delay" ) );
	
	set_zombie_var( "zombie_powerup_drop_increment", 	100000 );
	level.zombie_move_speed = 105;
	level.dog_health = 1600;
	level.dog_round_count = 5;
	level.game_started = 1;
	level.next_dog_round = 666;
	level.next_monkey_round = 666;
	level.next_doc_round = 666;

	for( ;; )
	{

		//////////////////////////////////////////
		//designed by prod DT#36173
		maxreward = 50 * level.round_number;
		if ( maxreward > 500 )
			maxreward = 500;
		level.zombie_vars["rebuild_barrier_cap_per_round"] = maxreward;
		//////////////////////////////////////////

		level.pro_tips_start_time = GetTime();
		level.zombie_last_run_time = GetTime();	// Resets the last time a zombie ran
	
        level thread maps\_zombiemode_audio::change_zombie_music( "round_start" );
		chalk_one_up();
		//		round_text( &"ZOMBIE_ROUND_BEGIN" );

		maps\_zombiemode_powerups::powerup_round_start();

		players = get_players();
		array_thread( players, maps\_zombiemode_blockers::rebuild_barrier_reward_reset );

		//array_thread( players, maps\_zombiemode_ability::giveHardpointItems );

		level thread award_grenades_for_survivors();

		bbPrint( "zombie_rounds: round %d player_count %d", level.round_number, players.size );

		level.round_start_time = GetTime();
		level thread [[level.round_spawn_func]]();

		level notify( "start_of_round" );

		//reset kill tracker at the beginning of every round -TTS
		level.global_zombies_killed_round = 0;
		level.current_round_start_time = int(gettime() / 1000);

		//level thread hud_sph();

		//This makes it so starting on a particular round makes the spawn delay
		//Be consistent with the round you skip to. -TTS
		level.zombie_vars["zombie_spawn_delay"] = 2;
		timer = level.zombie_vars["zombie_spawn_delay"];
		for(i = 0; i < level.round_number; i++) {
			if(level.zombie_vars["zombie_spawn_delay"] > .08) {
				level.zombie_vars["zombie_spawn_delay"] = level.zombie_vars["zombie_spawn_delay"] * .95;
			}			
			else if(level.zombie_vars["zombie_spawn_delay"] < .08) {
				level.zombie_vars["zombie_spawn_delay"] = .08;
			}
		}

		[[level.round_wait_func]]();

		level.first_round = false;
		level notify( "end_of_round" );
		level.current_round_end_time = int(gettime() / 1000);
		
		level thread maps\_zombiemode_audio::change_zombie_music( "round_end" );
		
		UploadStats();

		if ( 1 != players.size )
		{
			level thread spectators_respawn();
			//level thread last_stand_revive();
		}

		//		round_text( &"ZOMBIE_ROUND_END" );
		level chalk_round_over();

		level.round_number++;

		level notify( "between_round_over" );
	}
}


award_grenades_for_survivors()
{
	players = get_players();

	for (i = 0; i < players.size; i++)
	{
		if (!players[i].is_zombie)
		{
			lethal_grenade = players[i] get_player_lethal_grenade();
			if( !players[i] HasWeapon( lethal_grenade ) )
			{
				players[i] GiveWeapon( lethal_grenade );	
				players[i] SetWeaponAmmoClip( lethal_grenade, 0 );
			}

			if ( players[i] GetFractionMaxAmmo( lethal_grenade ) < .25 )
			{
				players[i] SetWeaponAmmoClip( lethal_grenade, 2 );
			}
			else if (players[i] GetFractionMaxAmmo( lethal_grenade ) < .5 )
			{
				players[i] SetWeaponAmmoClip( lethal_grenade, 3 );
			}
			else
			{
				players[i] SetWeaponAmmoClip( lethal_grenade, 4 );
			}
		}
	}
}

ai_calculate_health( round_number )
{
	level.zombie_health = level.zombie_vars["zombie_health_start"]; 
	for ( i=2; i<=round_number; i++ )
	{
		// After round 10, get exponentially harder
		if( i >= 10 )
		{
			level.zombie_health += Int( level.zombie_health * level.zombie_vars["zombie_health_increase_multiplier"] ); 
		}
		else
		{
			level.zombie_health = Int( level.zombie_health + level.zombie_vars["zombie_health_increase"] ); 
		}
	}
}

/#
round_spawn_failsafe_debug()
{
	level notify( "failsafe_debug_stop" );
	level endon( "failsafe_debug_stop" );

	start = GetTime();
	level.chunk_time = 0;

	while ( 1 )
	{
		level.failsafe_time = GetTime() - start;

		if ( isdefined( self.lastchunk_destroy_time ) )
		{
			level.chunk_time = GetTime() - self.lastchunk_destroy_time;
		}
		wait_network_frame();
	}
}
#/


//put the conditions in here which should
//cause the failsafe to reset
round_spawn_failsafe()
{
	self endon("death");//guy just died

	//////////////////////////////////////////////////////////////
	//FAILSAFE "hack shit"  DT#33203
	//////////////////////////////////////////////////////////////
	prevorigin = self.origin;
	while(1)
	{
		if( !level.zombie_vars["zombie_use_failsafe"] )
		{
			return;
		}

		if ( is_true( self.ignore_round_spawn_failsafe ) )
		{
			return;
		}

		wait( 30 );

		//if i've torn a board down in the last 8 seconds, just 
		//wait 30 again.
		if ( isDefined(self.lastchunk_destroy_time) )
		{
			if ( (GetTime() - self.lastchunk_destroy_time) < 8000 )
				continue; 
		}

		//fell out of world
		if ( self.origin[2] < level.zombie_vars["below_world_check"] )
		{
			if(is_true(level.put_timed_out_zombies_back_in_queue ) && !flag("dog_round") )
			{
				level.zombie_total++;	
			}			
			self dodamage( self.health + 100, (0,0,0) );				
			break;
		}

		//hasnt moved 24 inches in 30 seconds?	
		if ( DistanceSquared( self.origin, prevorigin ) < 576 ) 
		{
			
			//add this zombie back into the spawner queue to be re-spawned
			if(is_true(level.put_timed_out_zombies_back_in_queue ) && !flag("dog_round"))
			{
				//only if they have crawled thru a window and then timed out
				if(!self.ignoreall && !is_true(self.nuked) && !is_true(self.marked_for_death))
				{
					level.zombie_total++;	
				}
			}
			
			//add this to the stats even tho he really didn't 'die' 
			level.zombies_timeout_playspace++;
			
			// DEBUG HACK
			self dodamage( self.health + 100, (0,0,0) );
			break;
		}

		prevorigin = self.origin;
	}
	//////////////////////////////////////////////////////////////
	//END OF FAILSAFE "hack shit"
	//////////////////////////////////////////////////////////////
}

// Waits for the time and the ai to die
round_wait()
{
/#
    if (GetDvarInt( #"zombie_rise_test") )
	{
		level waittill("forever"); // TESTING: don't advance rounds
	}
#/

/#
	if ( GetDvarInt( #"zombie_cheat" ) == 2 || GetDvarInt( #"zombie_cheat" ) >= 4 )
	{
		level waittill("forever");
	}
#/

	wait( 1 );

	if( flag("dog_round" ) )
	{
		wait(7);
		while( level.dog_intermission )
		{
			wait(0.5);
		}
	}
	else
	{
		while( get_enemy_count() > 0 || level.zombie_total > 0 || level.intermission )
		{
			if( flag( "end_round_wait" ) )
			{
				return;
			}
			wait( 1.0 );
		}
	}
}


is_friendly_fire_on()
{
	return level.mutators[ "mutator_friendlyFire" ];
}


can_revive( reviver )
{
	if( self has_powerup_weapon() )
	{
		return false;
	}
	
	return true;
}


zombify_player()
{
	self maps\_zombiemode_score::player_died_penalty(); 

	bbPrint( "zombie_playerdeaths: round %d playername %s deathtype died x %f y %f z %f", level.round_number, self.playername, self.origin );

	if ( IsDefined( level.deathcard_spawn_func ) )
	{
		self [[level.deathcard_spawn_func]]();
	}

	if( !IsDefined( level.zombie_vars["zombify_player"] ) || !level.zombie_vars["zombify_player"] )
	{
		if (!is_true(self.solo_respawn ))
		{
			self thread spawnSpectator(); 
		}

		return; 
	}

	self.ignoreme = true; 
	self.is_zombie = true; 
	self.zombification_time = GetTime(); 

	self.team = "axis"; 
	self notify( "zombified" ); 

	if( IsDefined( self.revivetrigger ) )
	{
		self.revivetrigger Delete(); 
	}
	self.revivetrigger = undefined; 

	self setMoveSpeedScale( 0.3 ); 
	self reviveplayer(); 

	self TakeAllWeapons(); 
	//self starttanning(); 
	self GiveWeapon( "zombie_melee", 0 ); 
	self SwitchToWeapon( "zombie_melee" ); 
	self DisableWeaponCycling(); 
	self DisableOffhandWeapons(); 
	self VisionSetNaked( "zombie_turned", 1 ); 

	maps\_utility::setClientSysState( "zombify", 1, self ); 	// Zombie grain goooo

	self thread maps\_zombiemode_spawner::zombie_eye_glow(); 

	// set up the ground ref ent
	self thread injured_walk(); 
	// allow for zombie attacks, but they lose points?

	self thread playerzombie_player_damage(); 
	self thread playerzombie_soundboard(); 
}

playerzombie_player_damage()
{
	self endon( "death" ); 
	self endon( "disconnect" ); 

	self thread playerzombie_infinite_health();  // manually keep regular health up
	self.zombiehealth = level.zombie_health; 

	// enable PVP damage on this guy
	// self EnablePvPDamage(); 

	while( 1 )
	{
		self waittill( "damage", amount, attacker, directionVec, point, type ); 

		if( !IsDefined( attacker ) || !IsPlayer( attacker ) )
		{
			wait( 0.05 ); 
			continue; 
		}

		self.zombiehealth -= amount; 

		if( self.zombiehealth <= 0 )
		{
			// "down" the zombie
			self thread playerzombie_downed_state(); 
			self waittill( "playerzombie_downed_state_done" ); 
			self.zombiehealth = level.zombie_health; 
		}
	}
}

playerzombie_downed_state()
{
	self endon( "death" ); 
	self endon( "disconnect" ); 

	downTime = 15; 

	startTime = GetTime(); 
	endTime = startTime +( downTime * 1000 ); 

	self thread playerzombie_downed_hud(); 

	self.playerzombie_soundboard_disable = true; 
	self thread maps\_zombiemode_spawner::zombie_eye_glow_stop(); 
	self DisableWeapons(); 
	self AllowStand( false ); 
	self AllowCrouch( false ); 
	self AllowProne( true ); 

	while( GetTime() < endTime )
	{
		wait( 0.05 ); 
	}

	self.playerzombie_soundboard_disable = false; 
	self thread maps\_zombiemode_spawner::zombie_eye_glow(); 
	self EnableWeapons(); 
	self AllowStand( true ); 
	self AllowCrouch( false ); 
	self AllowProne( false ); 

	self notify( "playerzombie_downed_state_done" ); 
}

playerzombie_downed_hud()
{
	self endon( "death" ); 
	self endon( "disconnect" ); 

	text = NewClientHudElem( self ); 
	text.alignX = "center"; 
	text.alignY = "middle"; 
	text.horzAlign = "user_center"; 
	text.vertAlign = "user_bottom"; 
	text.foreground = true; 
	text.font = "default"; 
	text.fontScale = 1.8; 
	text.alpha = 0; 
	text.color = ( 1.0, 1.0, 1.0 ); 
	text SetText( &"ZOMBIE_PLAYERZOMBIE_DOWNED" ); 

	text.y = -113; 	
	if( IsSplitScreen() )
	{
		text.y = -137; 
	}

	text FadeOverTime( 0.1 ); 
	text.alpha = 1; 

	self waittill( "playerzombie_downed_state_done" ); 

	text FadeOverTime( 0.1 ); 
	text.alpha = 0; 
}

playerzombie_infinite_health()
{
	self endon( "death" ); 
	self endon( "disconnect" ); 

	bighealth = 100000; 

	while( 1 )
	{
		if( self.health < bighealth )
		{
			self.health = bighealth; 
		}

		wait( 0.1 ); 
	}
}

playerzombie_soundboard()
{
	self endon( "death" ); 
	self endon( "disconnect" ); 

	self.playerzombie_soundboard_disable = false; 

	self.buttonpressed_use = false; 
	self.buttonpressed_attack = false; 
	self.buttonpressed_ads = false; 

	self.useSound_waitTime = 3 * 1000;  // milliseconds
	self.useSound_nextTime = GetTime(); 
	useSound = "playerzombie_usebutton_sound"; 

	self.attackSound_waitTime = 3 * 1000; 
	self.attackSound_nextTime = GetTime(); 
	attackSound = "playerzombie_attackbutton_sound"; 

	self.adsSound_waitTime = 3 * 1000; 
	self.adsSound_nextTime = GetTime(); 
	adsSound = "playerzombie_adsbutton_sound"; 

	self.inputSound_nextTime = GetTime();  // don't want to be able to do all sounds at once

	while( 1 )
	{
		if( self.playerzombie_soundboard_disable )
		{
			wait( 0.05 ); 
			continue; 
		}

		if( self UseButtonPressed() )
		{
			if( self can_do_input( "use" ) )
			{
				self thread playerzombie_play_sound( useSound ); 
				self thread playerzombie_waitfor_buttonrelease( "use" ); 
				self.useSound_nextTime = GetTime() + self.useSound_waitTime; 
			}
		}
		else if( self AttackButtonPressed() )
		{
			if( self can_do_input( "attack" ) )
			{
				self thread playerzombie_play_sound( attackSound ); 
				self thread playerzombie_waitfor_buttonrelease( "attack" ); 
				self.attackSound_nextTime = GetTime() + self.attackSound_waitTime; 
			}
		}
		else if( self AdsButtonPressed() )
		{
			if( self can_do_input( "ads" ) )
			{
				self thread playerzombie_play_sound( adsSound ); 
				self thread playerzombie_waitfor_buttonrelease( "ads" ); 
				self.adsSound_nextTime = GetTime() + self.adsSound_waitTime; 
			}
		}

		wait( 0.05 ); 
	}
}

can_do_input( inputType )
{
	if( GetTime() < self.inputSound_nextTime )
	{
		return false; 
	}

	canDo = false; 

	switch( inputType )
	{
	case "use":
		if( GetTime() >= self.useSound_nextTime && !self.buttonpressed_use )
		{
			canDo = true; 
		}
		break; 

	case "attack":
		if( GetTime() >= self.attackSound_nextTime && !self.buttonpressed_attack )
		{
			canDo = true; 
		}
		break; 

	case "ads":
		if( GetTime() >= self.useSound_nextTime && !self.buttonpressed_ads )
		{
			canDo = true; 
		}
		break; 

	default:
		ASSERTMSG( "can_do_input(): didn't recognize inputType of " + inputType ); 
		break; 
	}

	return canDo; 
}

playerzombie_play_sound( alias )
{
	self play_sound_on_ent( alias ); 
}

playerzombie_waitfor_buttonrelease( inputType )
{
	if( inputType != "use" && inputType != "attack" && inputType != "ads" )
	{
		ASSERTMSG( "playerzombie_waitfor_buttonrelease(): inputType of " + inputType + " is not recognized." ); 
		return; 
	}

	notifyString = "waitfor_buttonrelease_" + inputType; 
	self notify( notifyString ); 
	self endon( notifyString ); 

	if( inputType == "use" )
	{
		self.buttonpressed_use = true; 
		while( self UseButtonPressed() )
		{
			wait( 0.05 ); 
		}
		self.buttonpressed_use = false; 
	}

	else if( inputType == "attack" )
	{
		self.buttonpressed_attack = true; 
		while( self AttackButtonPressed() )
		{
			wait( 0.05 ); 
		}
		self.buttonpressed_attack = false; 
	}

	else if( inputType == "ads" )
	{
		self.buttonpressed_ads = true; 
		while( self AdsButtonPressed() )
		{
			wait( 0.05 ); 
		}
		self.buttonpressed_ads = false; 
	}
}

remove_ignore_attacker()
{
	self notify( "new_ignore_attacker" );
	self endon( "new_ignore_attacker" );
	self endon( "disconnect" );
	
	if( !isDefined( level.ignore_enemy_timer ) )
	{
		level.ignore_enemy_timer = 0.4;
	}
	
	wait( level.ignore_enemy_timer );
	
	self.ignoreAttacker = undefined;
}

player_damage_override_cheat( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, sWeapon, vPoint, vDir, sHitLoc, modelIndex, psOffsetTime )
{
	player_damage_override( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, sWeapon, vPoint, vDir, sHitLoc, modelIndex, psOffsetTime );
	return 0;
}


//
//	player_damage_override
//		MUST return the value of the damage override
//
// MM (08/10/09) - Removed calls to PlayerDamageWrapper because it's always called in 
//		Callback_PlayerDamage now.  We just need to return the damage.
//
player_damage_override( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, sWeapon, vPoint, vDir, sHitLoc, modelIndex, psOffsetTime )
{
	iDamage = self check_player_damage_callbacks( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, sWeapon, vPoint, vDir, sHitLoc, modelIndex, psOffsetTime );
	if ( !iDamage )
	{
		return 0;
	}

	// WW (8/14/10) - If a player is hit by the crossbow bolt then set them as the holder of the monkey shot
	if( sWeapon == "crossbow_explosive_upgraded_zm" && sMeansOfDeath == "MOD_IMPACT" )
	{
		level.monkey_bolt_holder = self;
	}
	
	// Raven - snigl - Notify of blow gun hit
	if( GetSubStr(sWeapon, 0, 8 ) == "blow_gun" && sMeansOfDeath == "MOD_IMPACT" )
	{
		eAttacker notify( "blow_gun_hit", self, eInflictor );
	}
	
	// WW (8/20/10) - Sledgehammer fix for Issue 43492. This should stop the player from taking any damage while in laststand
	if( self maps\_laststand::player_is_in_laststand() )
	{
		return 0;
	}

	if ( isDefined( eInflictor ) )
	{
		if ( is_true( eInflictor.water_damage ) )
		{
			return 0;
		}
	}

	if( isDefined( eAttacker ) )
	{
		
		//tracking player damage
		if(is_true(eAttacker.is_zombie))
		{
			self.stats["damage_taken"] += iDamage;
		}
		
		if( isDefined( self.ignoreAttacker ) && self.ignoreAttacker == eAttacker ) 
		{
			return 0;
		}
		
		if( (isDefined( eAttacker.is_zombie ) && eAttacker.is_zombie) || level.mutators["mutator_friendlyFire"] )
		{
			self.ignoreAttacker = eAttacker;
			self thread remove_ignore_attacker();

			if ( isdefined( eAttacker.custom_damage_func ) )
			{
				iDamage = eAttacker [[ eAttacker.custom_damage_func ]]( self );
			}
			else if ( isdefined( eAttacker.meleeDamage ) )
			{
				iDamage = eAttacker.meleeDamage;
			}
			else
			{
				iDamage = 50;		// 45
			}
		}
		
		eAttacker notify( "hit_player" ); 
		
		
		if( is_true(eattacker.is_zombie) && eattacker.animname == "director_zombie" )
		{
			 self PlaySound( "zmb_director_light_hit" );
			 if(RandomIntRange(0,1) == 0 )
		    {
		        self thread maps\_zombiemode_audio::create_and_play_dialog( "general", "hitmed" );
		    }
		    else
		    {
		        self thread maps\_zombiemode_audio::create_and_play_dialog( "general", "hitlrg" );
		    }
		} 
		else if( sMeansOfDeath != "MOD_FALLING" )
		{
		    self PlaySound( "evt_player_swiped" );
		    if(RandomIntRange(0,1) == 0 )
		    {
		        self thread maps\_zombiemode_audio::create_and_play_dialog( "general", "hitmed" );
		    }
		    else
		    {
		        self thread maps\_zombiemode_audio::create_and_play_dialog( "general", "hitlrg" );
		    }
		}
	}
	finalDamage = iDamage;
	
	// claymores and freezegun shatters, like bouncing betties, harm no players
	if ( is_placeable_mine( sWeapon ) || sWeapon == "freezegun_zm" || sWeapon == "freezegun_upgraded_zm" )
	{
		return 0;
	}

	if ( isDefined( self.player_damage_override ) )
	{
		self thread [[ self.player_damage_override ]]( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, sWeapon, vPoint, vDir, sHitLoc, modelIndex, psOffsetTime );
	}

	if( sMeansOfDeath == "MOD_FALLING" )
	{
		if ( self HasPerk( "specialty_flakjacket" ) && isdefined( self.divetoprone ) && self.divetoprone == 1 )
		{
			if ( IsDefined( level.zombiemode_divetonuke_perk_func ) )
			{
				[[ level.zombiemode_divetonuke_perk_func ]]( self, self.origin );
			}

			return 0;
		}
	}

	if( sMeansOfDeath == "MOD_PROJECTILE" || sMeansOfDeath == "MOD_PROJECTILE_SPLASH" || sMeansOfDeath == "MOD_GRENADE" || sMeansOfDeath == "MOD_GRENADE_SPLASH" )
	{
		// check for reduced damage from flak jacket perk
		if ( self HasPerk( "specialty_flakjacket" ) )
		{
			return 0;
		}

		if( self.health > 75 )
		{
			// MM (08/10/09)
			return 75;
		}
	}

	if( iDamage < self.health )
	{
		if ( IsDefined( eAttacker ) )
		{
			eAttacker.sound_damage_player = self;
			
			if( IsDefined( eAttacker.has_legs ) && !eAttacker.has_legs )
			{
			    self maps\_zombiemode_audio::create_and_play_dialog( "general", "crawl_hit" );
			}
			else if( IsDefined( eAttacker.animname ) && ( eAttacker.animname == "monkey_zombie" ) )
			{
			    self maps\_zombiemode_audio::create_and_play_dialog( "general", "monkey_hit" );
			}
		}
		
		// MM (08/10/09)
		return finalDamage;
	}
	if( level.intermission )
	{
		level waittill( "forever" );
	}

	players = get_players();
	count = 0;
	for( i = 0; i < players.size; i++ )
	{
		if( players[i] == self || players[i].is_zombie || players[i] maps\_laststand::player_is_in_laststand() || players[i].sessionstate == "spectator" )
		{
			count++;
		}
	}
	if( count < players.size )
	{
		// MM (08/10/09)
		return finalDamage;
	}

	//if ( maps\_zombiemode_solo::solo_has_lives() )
	//{
	//	SetDvar( "player_lastStandBleedoutTime", "3" );
	//}
	//else
	//{
	if ( players.size == 1 && flag( "solo_game" ) )
	{
		if ( self.lives == 0 )
		{
			self.intermission = true;
		}
	}
	//}
	
	// WW (01/05/11): When a two players enter a system link game and the client drops the host will be treated as if it was a solo game
	// when it wasn't. This led to SREs about undefined and int being compared on death (self.lives was never defined on the host). While
	// adding the check for the solo game flag we found that we would have to create a complex OR inside of the if check below. By breaking
	// the conditions out in to their own variables we keep the complexity without making it look like a mess.
	solo_death = ( players.size == 1 && flag( "solo_game" ) && self.lives == 0 ); // there is only one player AND the flag is set AND self.lives equals 0
	non_solo_death = ( players.size > 1 || ( players.size == 1 && !flag( "solo_game" ) ) ); // the player size is greater than one OR ( players.size equals 1 AND solo flag isn't set )

	if ( solo_death || non_solo_death ) // if only one player on their last life or any game that started with more than one player
	{
		self thread maps\_laststand::PlayerLastStand( eInflictor, eAttacker, iDamage, sMeansOfDeath, sWeapon, vDir, sHitLoc, psOffsetTime );
		self player_fake_death();
	}

	if( count == players.size )
	{
		//if ( !maps\_zombiemode_solo::solo_has_lives() )
		//{

		if ( players.size == 1 && flag( "solo_game" ) )
		{
			if ( self.lives == 0 ) // && !self maps\_laststand::player_is_in_laststand()
			{
				
				level notify("pre_end_game");
				wait_network_frame();
				
				level notify( "end_game" );
			}
			else
			{
				self thread wait_and_revive();
				return finalDamage;
			}
		}
		else
		{
			level notify("pre_end_game");
			wait_network_frame();
			
			level notify( "end_game" );
		}
		//}

		return 0;	// MM (09/16/09) Need to return something
	}
	else
	{
		// MM (08/10/09)
		return finalDamage;
	}
}


check_player_damage_callbacks( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, sWeapon, vPoint, vDir, sHitLoc, modelIndex, psOffsetTime )
{
	if ( !isdefined( level.player_damage_callbacks ) )
	{
		return iDamage;
	}

	for ( i = 0; i < level.player_damage_callbacks.size; i++ )
	{
		newDamage = self [[ level.player_damage_callbacks[i] ]]( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, sWeapon, vPoint, vDir, sHitLoc, modelIndex, psOffsetTime );
		if ( -1 != newDamage )
		{
			return newDamage;
		}
	}

	return iDamage;
}


register_player_damage_callback( func )
{
	if ( !isdefined( level.player_damage_callbacks ) )
	{
		level.player_damage_callbacks = [];
	}

	level.player_damage_callbacks[level.player_damage_callbacks.size] = func;
}


wait_and_revive()
{
	flag_set( "wait_and_revive" );

	if ( isdefined( self.waiting_to_revive ) && self.waiting_to_revive == true )
	{
		return;
	}

	self.waiting_to_revive = true;
	if ( isdefined( level.exit_level_func ) )
	{
		self thread [[ level.exit_level_func ]]();
	}
	else
	{
		self thread default_exit_level();
	}

	// wait to actually go into last stand before reviving
	while ( 1 )
	{
		if ( self maps\_laststand::player_is_in_laststand() )
		{
			break;
		}

		wait_network_frame();
	}

	solo_revive_time = 10.0;

	self.revive_hud setText( &"ZOMBIE_REVIVING_SOLO", self );
	self maps\_laststand::revive_hud_show_n_fade( solo_revive_time );

	flag_wait_or_timeout("instant_revive", solo_revive_time);

	flag_clear( "wait_and_revive" );

	self maps\_laststand::auto_revive( self );
	self.lives--;
	self.waiting_to_revive = false;
}

//
//		MUST return the value of the damage override
//
actor_damage_override( inflictor, attacker, damage, flags, meansofdeath, weapon, vpoint, vdir, sHitLoc, modelIndex, psOffsetTime )
{
	// WW (8/14/10) - define the owner of the monkey shot
	if( weapon == "crossbow_explosive_upgraded_zm" && meansofdeath == "MOD_IMPACT" ) 
	{
		level.monkey_bolt_holder = self;
	}
	
	// Raven - snigl - Record what the blow gun hit
	if( GetSubStr(weapon, 0, 8 ) == "blow_gun" && meansofdeath == "MOD_IMPACT" )
	{
		attacker notify( "blow_gun_hit", self, inflictor );
	}

	if ( isdefined( attacker.animname ) && attacker.animname == "quad_zombie" )
	{
		if ( isdefined( self.animname ) && self.animname == "quad_zombie" )
		{
			return 0;
		}
	}
	
	// skip conditions
	if( !isdefined( self) || !isdefined( attacker ) )
		return damage;
	if ( !isplayer( attacker ) && isdefined( self.non_attacker_func ) )
	{
		override_damage = self [[ self.non_attacker_func ]]( damage, weapon );
		if ( override_damage )
			return override_damage;
	}
	if ( !isplayer( attacker ) && !isplayer( self ) )
		return damage;
	if( !isdefined( damage ) || !isdefined( meansofdeath ) )
		return damage;
	if( meansofdeath == "" )
		return damage;

	

//	println( "*********HIT :  Zombie health: "+self.health+",  dam:"+damage+", weapon:"+ weapon );

	old_damage = damage;
	final_damage = damage;

	if ( IsDefined( self.actor_damage_func ) )
	{
		final_damage = [[ self.actor_damage_func ]]( weapon, old_damage, attacker );
	}

	if ( IsDefined( self.actor_full_damage_func ) )
	{
		final_damage = [[ self.actor_full_damage_func ]]( inflictor, attacker, damage, flags, meansofdeath, weapon, vpoint, vdir, sHitLoc, modelIndex, psOffsetTime );
	}

	// debug
/#
		if ( GetDvarInt( #"scr_perkdebug") )
			println( "Perk/> Damage Factor: " + final_damage/old_damage + " - Pre Damage: " + old_damage + " - Post Damage: " + final_damage );
#/
	
	if( attacker.classname == "script_vehicle" && isDefined( attacker.owner ) )
		attacker = attacker.owner;

	if( !isDefined( self.damage_assists ) )
	{
		self.damage_assists = [];
	}

	if ( !isdefined( self.damage_assists[attacker.entity_num] ) )
	{
		self.damage_assists[attacker.entity_num] = attacker;
	}

	if( level.mutators[ "mutator_headshotsOnly" ] && !is_headshot( weapon, sHitLoc, meansofdeath ) )
	{
		return 0;
	}

	if( level.mutators[ "mutator_powerShot" ] )
	{
		final_damage = int( final_damage * 1.5 );
	}

	if ( is_true( self.in_water ) )
	{
		if ( int( final_damage ) >= self.health )
		{
			self.water_damage = true;
		}
	}
	
	// return unchanged damage
	//iPrintln( final_damage );
	return int( final_damage );
}

is_headshot( sWeapon, sHitLoc, sMeansOfDeath )
{
	return (sHitLoc == "head" || sHitLoc == "helmet") && sMeansOfDeath != "MOD_MELEE" && sMeansOfDeath != "MOD_BAYONET" && sMeansOfDeath != "MOD_IMPACT"; //CoD5: MGs need to cause headshots as well. && !isMG( sWeapon );
}

actor_killed_override(eInflictor, attacker, iDamage, sMeansOfDeath, sWeapon, vDir, sHitLoc, psOffsetTime)
{
	if ( game["state"] == "postgame" )
		return;	
	
	if( isai(attacker) && isDefined( attacker.script_owner ) )
	{
		// if the person who called the dogs in switched teams make sure they don't
		// get penalized for the kill
		if ( attacker.script_owner.team != self.aiteam )
			attacker = attacker.script_owner;
	}
		
	if( attacker.classname == "script_vehicle" && isDefined( attacker.owner ) )
		attacker = attacker.owner;
		
	if( IsPlayer( level.monkey_bolt_holder ) && sMeansOfDeath == "MOD_GRENADE_SPLASH"
			&& ( sWeapon == "crossbow_explosive_upgraded_zm" || sWeapon == "explosive_bolt_upgraded_zm" ) ) // 
	{
		level._bolt_on_back = level._bolt_on_back + 1;
	}
	

	if ( isdefined( attacker ) && isplayer( attacker ) )
	{
		multiplier = 1;
		if( is_headshot( sWeapon, sHitLoc, sMeansOfDeath ) )
		{
			multiplier = 1.5;
		}

		type = undefined;

		//MM (3/18/10) no animname check
		if ( IsDefined(self.animname) )
		{
			switch( self.animname )
			{
			case "quad_zombie":
				type = "quadkill";
				break;
			case "ape_zombie":
				type = "apekill";
				break;
			case "zombie":
				type = "zombiekill";
				break;
			case "zombie_dog":
				type = "dogkill";
				break;
			}
		}
		//if( isDefined( type ) )
		//{
		//	value = maps\_zombiemode_rank::getScoreInfoValue( type );
		//	self process_assist( type, attacker );

		//	value = int( value * multiplier );
		//	attacker thread maps\_zombiemode_rank::giveRankXP( type, value, false, false );
		//}
	}
	
	if(is_true(self.is_ziplining))
	{
		self.deathanim = undefined;
	}

	if ( IsDefined( self.actor_killed_override ) )
	{
		self [[ self.actor_killed_override ]]( eInflictor, attacker, iDamage, sMeansOfDeath, sWeapon, vDir, sHitLoc, psOffsetTime );
	}

}


process_assist( type, attacker )
{
	if ( isDefined( self.damage_assists ) )
	{
		for ( j = 0; j < self.damage_assists.size; j++ )
		{
			player = self.damage_assists[j];
			
			if ( !isDefined( player ) )
				continue;
			
			if ( player == attacker )
				continue;
			
			//assist_xp = maps\_zombiemode_rank::getScoreInfoValue( type + "_assist" );
			//player thread maps\_zombiemode_rank::giveRankXP( type + "_assist", assist_xp );
		}
		self.damage_assists = undefined;
	}
}


end_game()
{
	level waittill ( "end_game" );
	
	clientnotify( "zesn" );
	level thread maps\_zombiemode_audio::change_zombie_music( "game_over" );
	
	//AYERS: Turn off ANY last stand audio at the end of the game
	players = get_players();
	for( i = 0; i < players.size; i++ )
	{
		setClientSysState( "lsm", "0", players[i] );
	}

	StopAllRumbles();

	level.intermission = true;
	level.zombie_vars["zombie_powerup_insta_kill_time"] = 0;
	level.zombie_vars["zombie_powerup_fire_sale_time"] = 0;
	level.zombie_vars["zombie_powerup_point_doubler_time"] = 0;
	wait 0.1;

	update_leaderboards();
	
	game_over = [];
	survived = [];
	
	players = get_players();
	for( i = 0; i < players.size; i++ )
	{
		game_over[i] = NewClientHudElem( players[i] );
		game_over[i].alignX = "center";
		game_over[i].alignY = "middle";
		game_over[i].horzAlign = "center";
		game_over[i].vertAlign = "middle";
		game_over[i].y -= 130;
		game_over[i].foreground = true;
		game_over[i].fontScale = 3;
		game_over[i].alpha = 0;
		game_over[i].color = ( 1.0, 1.0, 1.0 );
		game_over[i] SetText( &"ZOMBIE_GAME_OVER" );

		game_over[i] FadeOverTime( 1 );
		game_over[i].alpha = 1;
		if ( players[i] isSplitScreen() )
		{
			game_over[i].y += 40;
		}

		survived[i] = NewClientHudElem( players[i] );
		survived[i].alignX = "center";
		survived[i].alignY = "middle";
		survived[i].horzAlign = "center";
		survived[i].vertAlign = "middle";
		survived[i].y -= 100;
		survived[i].foreground = true;
		survived[i].fontScale = 2;
		survived[i].alpha = 0;
		survived[i].color = ( 1.0, 1.0, 1.0 );
		if ( players[i] isSplitScreen() )
		{
			survived[i].y += 40;
		}

		//OLD COUNT METHOD
		if( level.round_number < 2 )
		{
			if( level.script == "zombie_moon" )
			{
				if( !isdefined(level.left_nomans_land) )
				{
					nomanslandtime = level.nml_best_time; 
					player_survival_time = int( nomanslandtime/1000 ); 
					player_survival_time_in_mins = maps\_zombiemode::to_mins( player_survival_time );		
					survived[i] SetText( &"ZOMBIE_SURVIVED_NOMANS", player_survival_time_in_mins );
				}
				else if( level.left_nomans_land==2 )
				{
					survived[i] SetText( &"ZOMBIE_SURVIVED_ROUND" );
				}
			}
			else
			{
				survived[i] SetText( &"ZOMBIE_SURVIVED_ROUND" );
			}
		}
		else
		{
			survived[i] SetText( &"ZOMBIE_SURVIVED_ROUNDS", level.round_number );
		}

		survived[i] FadeOverTime( 1 );
		survived[i].alpha = 1;
	}

	players = get_players();
	for (i = 0; i < players.size; i++)
	{
		players[i] SetClientDvars( "ammoCounterHide", "1",
				"miniscoreboardhide", "1" );
		//players[i] maps\_zombiemode_solo::solo_destroy_lives_hud();
		//players[i] maps\_zombiemode_ability::clear_hud();
	}
	destroy_chalk_hud();

	UploadStats();

	wait( 1 );

	//play_sound_at_pos( "end_of_game", ( 0, 0, 0 ) );
	wait( 2 );
	intermission();
	wait( level.zombie_vars["zombie_intermission_time"] );

	level notify( "stop_intermission" );
	array_thread( get_players(), ::player_exit_level );

	bbPrint( "zombie_epilogs: rounds %d", level.round_number );

	players = get_players();
	for (i = 0; i < players.size; i++)
	{
		survived[i] FadeOverTime( 1 );
		survived[i].alpha = 0;
		game_over[i] FadeOverTime( 1 );
		game_over[i].alpha = 0;
	}

	wait( 1.5 );

	
/*	we are not currently supporting the shared screen tech
	if( IsSplitScreen() )
	{
		players = get_players();
		for( i = 0; i < players.size; i++ )
		{
			share_screen( players[i], false );
		}
	}
*/

	for ( j = 0; j < get_players().size; j++ )
	{
		player = get_players()[j];
		player CameraActivate( false );	

		survived[j] Destroy();
		game_over[j] Destroy();
	}
	
	if ( level.onlineGame || level.systemLink )
	{
		ExitLevel( false );
	}
	else
	{
		MissionFailed();
	}

	// Let's not exit the function
	wait( 666 );
}

update_leaderboards()
{
	uploadGlobalStatCounters();
	
	if ( GetPlayers().size <= 1 )
	{
		//Solo leaderboard!
		cheater_found = maps\_zombiemode_ffotd::nazizombies_checking_for_cheats();
		if( cheater_found == false )
		{
			//no cheater found - upload score and stats
			nazizombies_upload_solo_highscore();
		}
		return;
	}

	if( level.systemLink )
	{
		return; 
	}

	if ( GetDvarInt( #"splitscreen_playerCount" ) == GetPlayers().size )
	{
		return;
	}

	cheater_found = maps\_zombiemode_ffotd::nazizombies_checking_for_cheats();
	if( cheater_found == false )
	{
		//no cheater found - upload score and stats
		nazizombies_upload_highscore();
		nazizombies_set_new_zombie_stats();
	}
}

initializeStatTracking()
{
	level.global_zombies_killed = 0;
}

uploadGlobalStatCounters()
{
	incrementCounter( "global_zombies_killed", level.global_zombies_killed );
	incrementCounter( "global_zombies_killed_by_players", level.zombie_player_killed_count );
	incrementCounter( "global_zombies_killed_by_traps", level.zombie_trap_killed_count );	
}

player_fake_death()
{
	level notify ("fake_death");
	self notify ("fake_death");

	self TakeAllWeapons();
	self AllowProne( true );
	self AllowStand( false );
	self AllowCrouch( false );

	self.ignoreme = true;
	self EnableInvulnerability();

	wait( 1 );
	self FreezeControls( true );
}

player_exit_level()
{
	self AllowStand( true );
	self AllowCrouch( false );
	self AllowProne( false );

	if( IsDefined( self.game_over_bg ) )
	{
		self.game_over_bg.foreground = true;
		self.game_over_bg.sort = 100;
		self.game_over_bg FadeOverTime( 1 );
		self.game_over_bg.alpha = 1;
	}
}

player_killed_override()
{
	// BLANK
	level waittill( "forever" );
}


injured_walk()
{
	self.ground_ref_ent = Spawn( "script_model", ( 0, 0, 0 ) ); 

	self.player_speed = 50; 

	// TODO do death countdown	
	self AllowSprint( false ); 
	self AllowProne( false ); 
	self AllowCrouch( false ); 
	self AllowAds( false ); 
	self AllowJump( false ); 

	self PlayerSetGroundReferenceEnt( self.ground_ref_ent ); 
	self thread limp(); 
}

limp()
{
	level endon( "disconnect" ); 
	level endon( "death" ); 
	// TODO uncomment when/if SetBlur works again
	//self thread player_random_blur(); 

	stumble = 0; 
	alt = 0; 

	while( 1 )
	{
		velocity = self GetVelocity(); 
		player_speed = abs( velocity[0] ) + abs( velocity[1] ); 

		if( player_speed < 10 )
		{
			wait( 0.05 ); 
			continue; 
		}

		speed_multiplier = player_speed / self.player_speed; 

		p = RandomFloatRange( 3, 5 ); 
		if( RandomInt( 100 ) < 20 )
		{
			p *= 3; 
		}
		r = RandomFloatRange( 3, 7 ); 
		y = RandomFloatRange( -8, -2 ); 

		stumble_angles = ( p, y, r ); 
		stumble_angles = vector_scale( stumble_angles, speed_multiplier ); 

		stumble_time = RandomFloatRange( .35, .45 ); 
		recover_time = RandomFloatRange( .65, .8 ); 

		stumble++; 
		if( speed_multiplier > 1.3 )
		{
			stumble++; 
		}

		self thread stumble( stumble_angles, stumble_time, recover_time ); 

		level waittill( "recovered" ); 
	}
}

stumble( stumble_angles, stumble_time, recover_time, no_notify )
{
	stumble_angles = self adjust_angles_to_player( stumble_angles ); 

	self.ground_ref_ent RotateTo( stumble_angles, stumble_time, ( stumble_time/4*3 ), ( stumble_time/4 ) ); 
	self.ground_ref_ent waittill( "rotatedone" ); 

	base_angles = ( RandomFloat( 4 ) - 4, RandomFloat( 5 ), 0 ); 
	base_angles = self adjust_angles_to_player( base_angles ); 

	self.ground_ref_ent RotateTo( base_angles, recover_time, 0, ( recover_time / 2 ) ); 
	self.ground_ref_ent waittill( "rotatedone" ); 

	if( !IsDefined( no_notify ) )
	{
		level notify( "recovered" ); 
	}
}

adjust_angles_to_player( stumble_angles )
{
	pa = stumble_angles[0]; 
	ra = stumble_angles[2]; 

	rv = AnglesToRight( self.angles ); 
	fv = AnglesToForward( self.angles ); 

	rva = ( rv[0], 0, rv[1]*-1 ); 
	fva = ( fv[0], 0, fv[1]*-1 ); 
	angles = vector_scale( rva, pa ); 
	angles = angles + vector_scale( fva, ra ); 
	return angles +( 0, stumble_angles[1], 0 ); 
}

coop_player_spawn_placement()
{
	structs = getstructarray( "initial_spawn_points", "targetname" ); 

	temp_ent = Spawn( "script_model", (0,0,0) );
	for( i = 0; i < structs.size; i++ )
	{
		temp_ent.origin = structs[i].origin;
		temp_ent placeSpawnpoint();
		structs[i].origin = temp_ent.origin;
	}
	temp_ent Delete();

	flag_wait( "all_players_connected" ); 

	//chrisp - adding support for overriding the default spawning method

	players = get_players(); 

	for( i = 0; i < players.size; i++ )
	{
		players[i] setorigin( structs[i].origin ); 
		players[i] setplayerangles( structs[i].angles ); 
		players[i].spectator_respawn = structs[i];
	}
}


player_zombie_breadcrumb()
{
	self endon( "disconnect" ); 
	self endon( "spawned_spectator" ); 
	level endon( "intermission" );

	self.zombie_breadcrumbs = []; 
	self.zombie_breadcrumb_distance = 24 * 24; // min dist (squared) the player must move to drop a crumb
	self.zombie_breadcrumb_area_num = 3;	   // the number of "rings" the area breadcrumbs use
	self.zombie_breadcrumb_area_distance = 16; // the distance between each "ring" of the area breadcrumbs

	self store_crumb( self.origin ); 
	last_crumb = self.origin;

	self thread debug_breadcrumbs(); 

	while( 1 )
	{
		wait_time = 0.1;
		
	/#
		if( self isnotarget() )
		{
			wait( wait_time ); 
			continue;
		}
	#/
	
		//For cloaking ability
		//if( self.ignoreme )
		//{
		//	wait( wait_time ); 
		//	continue;
		//}


		store_crumb = true; 
		airborne = false;
		crumb = self.origin;

//TODO TEMP SCRIPT for vehicle testing Delete/comment when done
		if ( !self IsOnGround() && self isinvehicle() )
		{
			trace = bullettrace( self.origin + (0,0,10), self.origin, false, undefined );
			crumb = trace["position"];
		}

//TODO TEMP DISABLE for vehicle testing.  Uncomment when reverting
// 		if ( !self IsOnGround() )
// 		{
// 			airborne = true;
// 			store_crumb = false; 
// 			wait_time = 0.05;
// 		}
// 		
		if( !airborne && DistanceSquared( crumb, last_crumb ) < self.zombie_breadcrumb_distance )
		{
			store_crumb = false; 
		}

		if ( airborne && self IsOnGround() )
		{
			// player was airborne, store crumb now that he's on the ground
			store_crumb = true;
			airborne = false;
		}
		
		if( isDefined( level.custom_breadcrumb_store_func ) )
		{
			store_crumb = self [[ level.custom_breadcrumb_store_func ]]( store_crumb );
		}
		
		if( isDefined( level.custom_airborne_func ) )
		{
			airborne = self [[ level.custom_airborne_func ]]( airborne );
		}
		
		if( store_crumb )
		{
			debug_print( "Player is storing breadcrumb " + crumb );
			
			if( IsDefined(self.node) )
			{
				debug_print( "has closest node " );
			}
			
			last_crumb = crumb;
			self store_crumb( crumb );
		}

		wait( wait_time ); 
	}
}


store_crumb( origin )
{
	offsets = [];
	height_offset = 32;
	
	index = 0;
	for( j = 1; j <= self.zombie_breadcrumb_area_num; j++ )
	{
		offset = ( j * self.zombie_breadcrumb_area_distance );
		
		offsets[0] = ( origin[0] - offset, origin[1], origin[2] );
		offsets[1] = ( origin[0] + offset, origin[1], origin[2] );
		offsets[2] = ( origin[0], origin[1] - offset, origin[2] );
		offsets[3] = ( origin[0], origin[1] + offset, origin[2] );

		offsets[4] = ( origin[0] - offset, origin[1], origin[2] + height_offset );
		offsets[5] = ( origin[0] + offset, origin[1], origin[2] + height_offset );
		offsets[6] = ( origin[0], origin[1] - offset, origin[2] + height_offset );
		offsets[7] = ( origin[0], origin[1] + offset, origin[2] + height_offset );

		for ( i = 0; i < offsets.size; i++ )
		{
			self.zombie_breadcrumbs[index] = offsets[i];
			index++;
		}
	}
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////LEADERBOARD CODE///////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
to_mins( seconds )
{
	hours = 0; 
	minutes = 0; 
	
	if( seconds > 59 )
	{
		minutes = int( seconds / 60 );

		seconds = int( seconds * 1000 ) % ( 60 * 1000 );
		seconds = seconds * 0.001; 

		if( minutes > 59 )
		{
			hours = int( minutes / 60 );
			minutes = int( minutes * 1000 ) % ( 60 * 1000 );
			minutes = minutes * 0.001; 		
		}
	}

	if( hours < 10 )
	{
		hours = "0" + hours; 
	}

	if( minutes < 10 )
	{
		minutes = "0" + minutes; 
	}

	seconds = Int( seconds ); 
	if( seconds < 10 )
	{
		seconds = "0" + seconds; 
	}

	combined = "" + hours  + ":" + minutes  + ":" + seconds; 

	return combined; 
}

//This is used to upload the score to the solo leaderboard for the moon map(No Man's Land)
nazizombies_upload_solo_highscore()
{
	map_name = GetDvar( #"mapname" );

	if ( !isZombieLeaderboardAvailable( map_name, "kills" ) )
		return;

	players = get_players();		
	for( i = 0; i < players.size; i++ )
	{
		if( map_name == "zombie_moon" )
		{
			nomanslandtime = level.nml_best_time;
			nomansland_kills = level.nml_kills;
			nomansland_score = level.nml_score; 
			player_survival_time = int( nomanslandtime/1000 );
			total_score = nomansland_score;	//players[i].score_total;
			total_kills = nomansland_kills;	//players[i].kills;
			
			leaderboard_number = getZombieLeaderboardNumber( map_name, "kills" );
			
			rounds_survived = level.round_number;
			
			if( isdefined(level.nml_didteleport) && (level.nml_didteleport==false) )
			{
				rounds_survived = 0;
			}
			
/#				
			if( GetDvarInt( #"zombie_cheat" ) >= 1 )
			{
				level.devcheater = 1;
			}
			
			if( isdefined(level.devcheater) && level.devcheater )
			{
				rounds_survived = -1;
			}
#/			

			rankNumber = makeNMLRankNumberSolo( total_kills, total_score );
			if( !isdefined(level.round_number) )
			{
				level.round_number = 0;
			}
			
			if( !isdefined(level.nml_pap) )
			{
				level.nml_pap = 0;
			}
			if( !isdefined(level.nml_speed) )
			{
				level.nml_speed = 0;
			}
			if( !isdefined(level.nml_jugg) )
			{
				level.nml_jugg = 0;
			}
			

			if( !isdefined(level.sololb_build_number) )
			{
				level.sololb_build_number = 48;
			}

			players[i] UploadScore( leaderboard_number, int(rankNumber), total_kills, total_score, player_survival_time, rounds_survived, level.sololb_build_number, level.nml_pap, level.nml_speed, level.nml_jugg ); 
		}
	}
}

makeNMLRankNumberSolo( total_kills, total_score )
{
	maximum_survival_time = 108000;

	// Upper cap on total_kills is 2000
	if( total_kills > 2000 )
		total_kills = 2000;
	
	// Upper cap on player total score
	if( total_score > 99999 )
		total_score = 99999;

	
	//pad out ranking time.
	score_padding = "";
	if ( total_score < 10 )
		score_padding += "0000";
	else if( total_score < 100 )
		score_padding += "000";
	else if( total_score < 1000 )
		score_padding += "00";
	else if( total_score < 10000 )
		score_padding += "0";

	// Trying to make the rankNumber by combining kills with 5 digit padded points earned.
	rankNumber = total_kills + score_padding + total_score;

	return rankNumber;
}

//CODER MOD: TOMMY K
nazizombies_upload_highscore()
{
	// Nazi Zombie Leaderboards
	// nazi_zombie_prototype_waves = 13
	// nazi_zombie_prototype_points = 14

	// this has gotta be the dumbest way of doing this, but at 1:33am in the morning my brain is fried!
	playersRank = 1;
	if( level.players_playing == 1 )
		playersRank = 4;
	else if( level.players_playing == 2 )
		playersRank = 3;
	else if( level.players_playing == 3 )
		playersRank = 2;

	map_name = GetDvar( #"mapname" );

	if ( !isZombieLeaderboardAvailable( map_name, "waves" ) || !isZombieLeaderboardAvailable( map_name, "points" ) )
		return;

	players = get_players();		
	for( i = 0; i < players.size; i++ )
	{
		pre_highest_wave = players[i] playerZombieStatGet( map_name, "highestwave" ); 
		pre_time_in_wave = players[i] playerZombieStatGet( map_name, "timeinwave" );

		new_highest_wave = level.round_number + "" + playersRank;
		new_highest_wave = int( new_highest_wave );

		if( new_highest_wave >= pre_highest_wave )
		{
			if( players[i].zombification_time == 0 )
			{
				players[i].zombification_time = GetTime();
			}

			player_survival_time = players[i].zombification_time - level.round_start_time; 
			player_survival_time = int( player_survival_time/1000 ); 	
			
			/*
			if( map_name == "zombie_moon" )
			{
				nomanslandtime = level.nml_best_time ; 
				player_survival_time = int( nomanslandtime/1000 ); 
				//player_survival_time_in_mins = maps\_zombiemode::to_mins( player_survival_time );
				//IPrintLnBold( "NO MANS LAND = " + player_survival_time_in_mins ); 
			}	
			*/	

			if( new_highest_wave > pre_highest_wave || player_survival_time > pre_time_in_wave )
			{
				rankNumber = makeRankNumber( level.round_number, playersRank, player_survival_time );

				leaderboard_number = getZombieLeaderboardNumber( map_name, "waves" );

				players[i] UploadScore( leaderboard_number, int(rankNumber), level.round_number, player_survival_time, level.players_playing ); 
				//players[i] UploadScore( leaderboard_number, int(rankNumber), level.round_number ); 

				players[i] playerZombieStatSet( map_name, "highestwave", new_highest_wave );
				players[i] playerZombieStatSet( map_name, "timeinwave", player_survival_time );	
			}
		}

		pre_total_points = players[i] playerZombieStatGet( map_name, "totalpoints" );
		if( players[i].score_total > pre_total_points )
		{
			leaderboard_number = getZombieLeaderboardNumber( map_name, "points" );

			players[i] UploadScore( leaderboard_number, players[i].score_total, players[i].kills, level.players_playing ); 

			players[i] playerZombieStatSet( map_name, "totalpoints", players[i].score_total );	
		}
	}
}

isZombieLeaderboardAvailable( map, type )
{
	if ( !isDefined( level.zombieLeaderboardNumber[map] ) )
		return 0;
	
	if ( !isDefined( level.zombieLeaderboardNumber[map][type] ) )
		return 0;

	return 1;
}

getZombieLeaderboardNumber( map, type )
{
	if ( !isDefined( level.zombieLeaderboardNumber[map][type] ) )
		assertMsg( "Unknown leaderboard number for map " + map + "and type " + type );
	
	return level.zombieLeaderboardNumber[map][type];
}

getZombieStatVariable( map, variable )
{
	if ( !isDefined( level.zombieLeaderboardStatVariable[map][variable] ) )
		assertMsg( "Unknown stat variable " + variable + " for map " + map );
		
	return level.zombieLeaderboardStatVariable[map][variable];
}

playerZombieStatGet( map, variable )
{
	stat_variable = getZombieStatVariable( map, variable );
	result = self zombieStatGet( stat_variable );

	return result;
}

playerZombieStatSet( map, variable, value )
{
	stat_variable = getZombieStatVariable( map, variable );
	self zombieStatSet( stat_variable, value );
}

nazizombies_set_new_zombie_stats()
{
	players = get_players();		
	for( i = 0; i < players.size; i++ )
	{
		//grab stat and add final totals
		total_kills = players[i] zombieStatGet( "zombie_kills" ) + players[i].stats["kills"];
		total_points = players[i] zombieStatGet( "zombie_points" ) + players[i].stats["score"];
		total_rounds = players[i] zombieStatGet( "zombie_rounds" ) + (level.round_number - 1); // rounds survived
		total_downs = players[i] zombieStatGet( "zombie_downs" ) + players[i].stats["downs"];
		total_revives = players[i] zombieStatGet( "zombie_revives" ) + players[i].stats["revives"];
		total_perks = players[i] zombieStatGet( "zombie_perks_consumed" ) + players[i].stats["perks"];
		total_headshots = players[i] zombieStatGet( "zombie_heashots" ) + players[i].stats["headshots"];
		total_zombie_gibs = players[i] zombieStatGet( "zombie_gibs" ) + players[i].stats["zombie_gibs"];

		//set zombie stats
		players[i] zombieStatSet( "zombie_kills", total_kills );
		players[i] zombieStatSet( "zombie_points", total_points );
		players[i] zombieStatSet( "zombie_rounds", total_rounds );
		players[i] zombieStatSet( "zombie_downs", total_downs );
		players[i] zombieStatSet( "zombie_revives", total_revives );
		players[i] zombieStatSet( "zombie_perks_consumed", total_perks );
		players[i] zombieStatSet( "zombie_heashots", total_headshots );
		players[i] zombieStatSet( "zombie_gibs", total_zombie_gibs );
	}
}

makeRankNumber( wave, players, time )
{
	if( time > 86400 ) 
		time = 86400; // cap it at like 1 day, need to cap cause you know some muppet is gonna end up trying it

	//pad out time
	padding = "";
	if ( 10 > time )
		padding += "0000";
	else if( 100 > time )
		padding += "000";
	else if( 1000 > time )
		padding += "00";
	else if( 10000 > time )
		padding += "0";

	rank = wave + "" + players + padding + time;

	return rank;
}


//CODER MOD: TOMMY K
/*
=============
zombieStatGet

Returns the value of the named stat
=============
*/
zombieStatGet( dataName )
{
	if( level.systemLink )
	{
		return; 
	}
	if ( GetDvarInt( #"splitscreen_playerCount" ) == GetPlayers().size )
	{
		return;
	}

	return ( self getdstat( "PlayerStatsList", dataName ) );
}

//CODER MOD: TOMMY K
/*
=============
zombieStatSet

Sets the value of the named stat
=============
*/
zombieStatSet( dataName, value )
{
	if( level.systemLink )
	{
		return; 
	}
	if ( GetDvarInt( #"splitscreen_playerCount" ) == GetPlayers().size )
	{
		return;
	}

	self setdstat( "PlayerStatsList", dataName, value );
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//
// INTERMISSION =========================================================== //
//

intermission()
{
	level.intermission = true;
	level notify( "intermission" );

	players = get_players();
	for( i = 0; i < players.size; i++ )
	{
		setclientsysstate( "levelNotify", "zi", players[i] ); // Tell clientscripts we're in zombie intermission

		players[i] SetClientDvars( "cg_thirdPerson", "0",
			"cg_fov", "65" );

		players[i].health = 100; // This is needed so the player view doesn't get stuck
		players[i] thread [[level.custom_intermission]]();
	}

	wait( 0.25 );

	// Delay the last stand monitor so we are 100% sure the zombie intermission ("zi") is set on the cients
	players = get_players();
	for( i = 0; i < players.size; i++ )
	{
		setClientSysState( "lsm", "0", players[i] );
	}

	visionset = "zombie";
	if( IsDefined( level.zombie_vars["intermission_visionset"] ) )
	{
		visionset = level.zombie_vars["intermission_visionset"];
	}

	level thread maps\_utility::set_all_players_visionset( visionset, 2 );
	level thread zombie_game_over_death();
}

zombie_game_over_death()
{
	// Kill remaining zombies, in style!
	zombies = GetAiArray( "axis" );
	for( i = 0; i < zombies.size; i++ )
	{
		if( !IsAlive( zombies[i] ) )
		{
			continue;
		}

		zombies[i] SetGoalPos( zombies[i].origin );
	}

	for( i = 0; i < zombies.size; i++ )
	{
		if( !IsAlive( zombies[i] ) )
		{
			continue;
		}

		wait( 0.5 + RandomFloat( 2 ) );

		if ( isdefined( zombies[i] ) )
		{
			zombies[i] maps\_zombiemode_spawner::zombie_head_gib();
			zombies[i] DoDamage( zombies[i].health + 666, zombies[i].origin );
		}
	}
}

player_intermission()
{
	self closeMenu();
	self closeInGameMenu();

	level endon( "stop_intermission" );
	self endon("disconnect");
	self endon("death");
	self notify( "_zombie_game_over" ); // ww: notify so hud elements know when to leave

	//Show total gained point for end scoreboard and lobby
	self.score = self.score_total;

	self.sessionstate = "intermission";
	self.spectatorclient = -1; 
	self.killcamentity = -1; 
	self.archivetime = 0; 
	self.psoffsettime = 0; 
	self.friendlydamage = undefined;

	points = getstructarray( "intermission", "targetname" );

	if( !IsDefined( points ) || points.size == 0 )
	{
		points = getentarray( "info_intermission", "classname" ); 
		if( points.size < 1 )
		{
			println( "NO info_intermission POINTS IN MAP" ); 
			return;
		}	
	}

	self.game_over_bg = NewClientHudelem( self );
	self.game_over_bg.horzAlign = "fullscreen";
	self.game_over_bg.vertAlign = "fullscreen";
	self.game_over_bg SetShader( "black", 640, 480 );
	self.game_over_bg.alpha = 1;

	org = undefined;
	while( 1 )
	{
		points = array_randomize( points );
		for( i = 0; i < points.size; i++ )
		{
			point = points[i];
			// Only spawn once if we are using 'moving' org
			// If only using info_intermissions, this will respawn after 5 seconds.
			if( !IsDefined( org ) )
			{
				self Spawn( point.origin, point.angles );
			}

			// Only used with STRUCTS
			if( IsDefined( points[i].target ) )
			{
				if( !IsDefined( org ) )
				{
					org = Spawn( "script_model", self.origin + ( 0, 0, -60 ) );
					org SetModel("tag_origin");
				}

//				self LinkTo( org, "", ( 0, 0, -60 ), ( 0, 0, 0 ) );
//				self SetPlayerAngles( points[i].angles );
				org.origin = points[i].origin;
				org.angles = points[i].angles;
				

				for ( j = 0; j < get_players().size; j++ )
				{
					player = get_players()[j];
					player CameraSetPosition( org );
					player CameraSetLookAt();
					player CameraActivate( true );	
				}

				speed = 20;
				if( IsDefined( points[i].speed ) )
				{
					speed = points[i].speed;
				}

				target_point = getstruct( points[i].target, "targetname" );
				dist = Distance( points[i].origin, target_point.origin );
				time = dist / speed;

				q_time = time * 0.25;
				if( q_time > 1 )
				{
					q_time = 1;
				}

				self.game_over_bg FadeOverTime( q_time );
				self.game_over_bg.alpha = 0;

				org MoveTo( target_point.origin, time, q_time, q_time );
				org RotateTo( target_point.angles, time, q_time, q_time );
				wait( time - q_time );

				self.game_over_bg FadeOverTime( q_time );
				self.game_over_bg.alpha = 1;

				wait( q_time );
			}
			else
			{
				self.game_over_bg FadeOverTime( 1 );
				self.game_over_bg.alpha = 0;

				wait( 5 );
				
				self.game_over_bg thread fade_up_over_time(1);

				//wait( 1 );
			}
		}
	}
}

fade_up_over_time(t)
{
		self FadeOverTime( t );
		self.alpha = 1;
}

prevent_near_origin()
{
	while (1)
	{
		players = get_players();

		for (i = 0; i < players.size; i++)
		{
			for (q = 0; q < players.size; q++)
			{
				if (players[i] != players[q])
				{	
					if (check_to_kill_near_origin(players[i], players[q]))
					{
						p1_org = players[i].origin;
						p2_org = players[q].origin;

						wait 5;

						if (check_to_kill_near_origin(players[i], players[q]))
						{
							if ( (distance(players[i].origin, p1_org) < 30) && distance(players[q].origin, p2_org) < 30)
							{
								setsaveddvar("player_deathInvulnerableTime", 0);
								players[i] DoDamage( players[i].health + 1000, players[i].origin, undefined, undefined, "riflebullet" );
								setsaveddvar("player_deathInvulnerableTime", level.startInvulnerableTime);	
							}
						}
					}	
				}
			}	
		}

		wait 0.2;
	}
}

check_to_kill_near_origin(player1, player2)
{
	if (!isdefined(player1) || !isdefined(player2))
	{
		return false;		
	}

	if (distance(player1.origin, player2.origin) > 12)
	{
		return false;
	}

	if ( player1 maps\_laststand::player_is_in_laststand() || player2 maps\_laststand::player_is_in_laststand() )
	{
		return false;
	}

	if (!isalive(player1) || !isalive(player2))
	{
		return false;		
	}

	return true;
}


//
crawler_round_tracker()
{	
	level.crawler_round_count = 1;

	level.next_crawler_round = 4;

	sav_func = level.round_spawn_func;
	while ( 1 )
	{
		level waittill ( "between_round_over" );

/#
			if( GetDvarInt( #"force_crawlers" ) > 0 )
			{
				next_crawler_round = level.round_number; 
			}
#/

			if ( level.round_number == level.next_crawler_round )
			{
				sav_func = level.round_spawn_func;
				crawler_round_start();
				level.round_spawn_func = ::round_spawning;

				if ( IsDefined( level.next_dog_round ) )
				{
					level.next_crawler_round = level.next_dog_round + randomintrange( 2, 3 );
				}
				else
				{
					level.next_crawler_round = randomintrange( 4, 6 );
				}
/#
				get_players()[0] iprintln( "Next crawler round: " + level.next_crawler_round );
#/
			}
			else if ( flag( "crawler_round" ) )
			{
				crawler_round_stop();

				// Don't trample over the round_spawn_func setting
				if ( IsDefined( level.next_dog_round ) && 
					 level.next_dog_round == level.round_number )
				{
					level.round_spawn_func = sav_func;
				}

				level.crawler_round_count += 1;
			}			
	}	
}


crawler_round_start()
{
	flag_set( "crawler_round" );
	if(!IsDefined (level.crawlerround_nomusic))
	{
		level.crawlerround_nomusic = 0;
	}
	level.crawlerround_nomusic = 1;
	level notify( "crawler_round_starting" );
	clientnotify( "crawler_start" );
}


crawler_round_stop()
{
	flag_clear( "crawler_round" );

	if(!IsDefined (level.crawlerround_nomusic))
	{
		level.crawlerround_nomusic = 0;
	}
	level.crawlerround_nomusic = 0;
	level notify( "crawler_round_ending" );
	clientnotify( "crawler_stop" );
}

default_exit_level()
{
	zombies = GetAiArray( "axis" );
	for ( i = 0; i < zombies.size; i++ )
	{
		if ( is_true( zombies[i].ignore_solo_last_stand ) )
		{
			continue;
		}

		if ( isDefined( zombies[i].find_exit_point ) )
		{
			zombies[i] thread [[ zombies[i].find_exit_point ]]();
			continue;
		}

		if ( zombies[i].ignoreme )
		{
			zombies[i] thread default_delayed_exit();
		}
		else
		{
			zombies[i] thread default_find_exit_point();
		}
	}
}

default_delayed_exit()
{
	self endon( "death" );

	while ( 1 )
	{
		if ( !flag( "wait_and_revive" ) )
		{
			return;
		}

		// broke through the barricade, find an exit point
		if ( !self.ignoreme )
		{
			break;
		}
		wait_network_frame();
	}

	self thread default_find_exit_point();
}

default_find_exit_point()
{
	self endon( "death" );

	player = getplayers()[0];

	dist_zombie = 0;
	dist_player = 0;
	dest = 0;

	away = VectorNormalize( self.origin - player.origin );
	endPos = self.origin + vector_scale( away, 600 );

	locs = array_randomize( level.enemy_dog_locations );

	for ( i = 0; i < locs.size; i++ )
	{
		dist_zombie = DistanceSquared( locs[i].origin, endPos );
		dist_player = DistanceSquared( locs[i].origin, player.origin );

		if ( dist_zombie < dist_player )
		{
			dest = i;
			break;
		}
	}

	self notify( "stop_find_flesh" );
	self notify( "zombie_acquire_enemy" );

	self setgoalpos( locs[dest].origin );

	while ( 1 )
	{
		if ( !flag( "wait_and_revive" ) )
		{
			break;
		}
		wait_network_frame();
	}
	
	self thread maps\_zombiemode_spawner::find_flesh();
}

play_level_start_vox_delayed()
{
    wait(5);
    players = getplayers();
	num = RandomIntRange( 0, players.size );
	players[num] maps\_zombiemode_audio::create_and_play_dialog( "general", "intro" );
}


//show some stats on the screen ( debug only )
init_screen_stats()
{
		
	level.zombies_timeout_spawn_info = NewHudElem(); 
	level.zombies_timeout_spawn_info.alignX = "right"; 
	level.zombies_timeout_spawn_info.x = 100; 
	level.zombies_timeout_spawn_info.y = 80;
	level.zombies_timeout_spawn_info.label = "Timeout(Spawncloset): ";
	level.zombies_timeout_spawn_info.fontscale = 1.2;
	

	level.zombies_timeout_playspace_info = NewHudElem(); 
	level.zombies_timeout_playspace_info.alignX = "right"; 
	level.zombies_timeout_playspace_info.x = 100; 
	level.zombies_timeout_playspace_info.y = 95;
	level.zombies_timeout_playspace_info.label ="Timeout(Playspace): ";
	level.zombies_timeout_playspace_info.fontscale = 1.2;

	level.zombie_player_killed_count_info = NewHudElem(); 
	level.zombie_player_killed_count_info.alignX = "right"; 
	level.zombie_player_killed_count_info.x = 100; 
	level.zombie_player_killed_count_info.y = 110;
	level.zombie_player_killed_count_info.label = "Zombies killed by players: ";
	level.zombie_player_killed_count_info.fontscale = 1.2;

	level.zombie_trap_killed_count_info = NewHudElem(); 
	level.zombie_trap_killed_count_info.alignX = "right"; 
	level.zombie_trap_killed_count_info.x = 100; 
	level.zombie_trap_killed_count_info.y = 125;
	level.zombie_trap_killed_count_info.label = "Zombies killed by traps: ";
	level.zombie_trap_killed_count_info.fontscale = 1.2;

	level.zombie_pathing_failed_info = NewHudElem(); 
	level.zombie_pathing_failed_info.alignX = "right"; 
	level.zombie_pathing_failed_info.x = 100; 
	level.zombie_pathing_failed_info.y = 140;
	level.zombie_pathing_failed_info.label = "Pathing failed: ";
	level.zombie_pathing_failed_info.fontscale = 1.2;
	
	
	level.zombie_breadcrumb_failed_info = NewHudElem(); 
	level.zombie_breadcrumb_failed_info.alignX = "right"; 
	level.zombie_breadcrumb_failed_info.x = 100; 
	level.zombie_breadcrumb_failed_info.y = 155;
	level.zombie_breadcrumb_failed_info.label = "Breadcrumbs failed: ";
	level.zombie_breadcrumb_failed_info.fontscale = 1.2;
	
	
	level.player_0_distance_traveled_info = NewHudElem(); 
	level.player_0_distance_traveled_info.alignX = "right"; 
	level.player_0_distance_traveled_info.x = 100; 
	level.player_0_distance_traveled_info.y = 170;
	level.player_0_distance_traveled_info.label = "Player(0) Distance traveled: ";
	level.player_0_distance_traveled_info.fontscale = 1.2;
	
}

update_screen_stats()
{
	flag_wait("all_players_spawned");
	while(1)
	{
		wait(1);
		
		if(getdvarint("zombie_show_stats") == 0)
		{
			level.zombies_timeout_spawn_info.alpha = 0;
			level.zombies_timeout_playspace_info.alpha = 0;
			level.zombie_player_killed_count_info.alpha = 0;
			level.zombie_trap_killed_count_info.alpha = 0; 
			level.zombie_pathing_failed_info.alpha = 0; 
			level.zombie_breadcrumb_failed_info.alpha = 0;
			level.player_0_distance_traveled_info.alpha = 0;
			continue;
		}
		else
		{
			level.zombies_timeout_spawn_info.alpha = 1;
			level.zombies_timeout_playspace_info.alpha = 1;
			level.zombie_player_killed_count_info.alpha = 1;
			level.zombie_trap_killed_count_info.alpha = 1; 
			level.zombie_pathing_failed_info.alpha = 1; 
			level.zombie_breadcrumb_failed_info.alpha = 1;
			level.player_0_distance_traveled_info.alpha = 1;
			
			level.zombies_timeout_spawn_info setValue( level.zombies_timeout_spawn );
			level.zombies_timeout_playspace_info SetValue(level.zombies_timeout_playspace );
			level.zombie_player_killed_count_info SetValue( level.zombie_player_killed_count);
			level.zombie_trap_killed_count_info SetValue( level.zombie_trap_killed_count);
			level.zombie_pathing_failed_info SetValue( level.zombie_pathing_failed );
			level.zombie_breadcrumb_failed_info SetValue( level.zombie_breadcrumb_failed );		
			level.player_0_distance_traveled_info SetValue( get_players()[0].stats["distance_traveled"] );
		}
	}
}


register_sidequest( id, solo_stat, solo_collectible, coop_stat, coop_collectible )
{
	if ( !IsDefined( level.zombie_sidequest_solo_stat ) )
	{
		level.zombie_sidequest_previously_completed = [];
		level.zombie_sidequest_solo_stat = [];
		level.zombie_sidequest_solo_collectible = [];
		level.zombie_sidequest_coop_stat = [];
		level.zombie_sidequest_coop_collectible = [];
	}
	
	level.zombie_sidequest_solo_stat[id] = solo_stat;
	level.zombie_sidequest_solo_collectible[id] = solo_collectible;
	level.zombie_sidequest_coop_stat[id] = coop_stat;
	level.zombie_sidequest_coop_collectible[id] = coop_collectible;

	flag_wait( "all_players_spawned" );

	level.zombie_sidequest_previously_completed[id] = false;
	if ( flag( "solo_game" ) )
	{
		if ( IsDefined( level.zombie_sidequest_solo_collectible[id] ) )
		{
			level.zombie_sidequest_previously_completed[id] = HasCollectible( level.zombie_sidequest_solo_collectible[id] );
		}
	}
	else
	{
		// don't do stats stuff if it's not an online game
		if ( level.systemLink || GetDvarInt( #"splitscreen_playerCount" ) == GetPlayers().size )
		{
			if ( IsDefined( level.zombie_sidequest_coop_collectible[id] ) )
			{
				level.zombie_sidequest_previously_completed[id] = HasCollectible( level.zombie_sidequest_coop_collectible[id] );
			}
			return;
		}
		
		if ( !isdefined( level.zombie_sidequest_coop_stat[id] ) )
		{
			return;
		}

		players = get_players();
		for ( i = 0; i < players.size; i++ )
		{
			if ( players[i] zombieStatGet( level.zombie_sidequest_coop_stat[id] ) )
			{
				level.zombie_sidequest_previously_completed[id] = true;
				return;
			}
		}
	}
}


is_sidequest_previously_completed(id)
{
	return is_true( level.zombie_sidequest_previously_completed[id] );
}


set_sidequest_completed(id)
{
	if ( maps\_cheat::is_cheating() || flag( "has_cheated" ) )
	{
		return;
	}

	if ( flag( "solo_game" ) )
	{
		client_notify_str = "SQS";
	}
	else
	{
		client_notify_str = "SQC";
	}
	clientnotify( client_notify_str ); // updates the collectibles value

	level notify( "zombie_sidequest_completed", id );
	level.zombie_sidequest_previously_completed[id] = true;

	// don't do stats stuff if it's not an online game
	if ( level.systemLink )
	{
		return; 
	}
	if ( GetDvarInt( #"splitscreen_playerCount" ) == GetPlayers().size )
	{
		return;
	}

	players = get_players();
	for ( i = 0; i < players.size; i++ )
	{
		if ( isdefined( level.zombie_sidequest_solo_stat[id] ) )
		{
			players[i] zombieStatSet( level.zombie_sidequest_solo_stat[id], (players[i] zombieStatGet( level.zombie_sidequest_solo_stat[id] ) + 1) );
		}

		if ( !flag( "solo_game" ) && isdefined( level.zombie_sidequest_coop_stat[id] ) )
		{
			players[i] zombieStatSet( level.zombie_sidequest_coop_stat[id], (players[i] zombieStatGet( level.zombie_sidequest_coop_stat[id] ) + 1) );
		}
	}
}

open_doors()
{	
	if( getDvar( "open_doors" ) == "" )
		setDvar( "open_doors", 1 );

	while(1)
	{
		if( getDvarInt( "open_doors" ) == 1 )
		{
			doors = getentarray( "zombie_door", "targetname" );
			for ( i = 0; i < doors.size; i++ )
			{	
				if ( level.script == "zombie_theater" &&  doors[i].target == "alley_door2" )
					continue;
				else if ( level.script == "zombie_theater" && doors[i].target == "backstage_door" )
					continue;
				else if ( level.script == "zombie_theater" && doors[i].target == "vip_top_door" )
					continue;
				else if ( level.script == "zombie_cod5_asylum" && doors[i].target == "auto228" )
					continue;
				else if ( level.script == "zombie_cod5_asylum" && doors[i].target == "auto76" )
					continue;
				else if ( level.script == "zombie_cosmodrome" && i == 1 )
					continue;
				else if ( level.script == "zombie_cosmodrome" && i == 2 )
					continue;
				else if ( level.script == "zombie_cosmodrome" && i == 4 )
					continue;
				if ( level.script == "zombie_temple" && i == 0 )
					continue;
				else if ( level.script == "zombie_cod5_sumpf" && doors[i].target == "nw_hut_blocker" )
					continue;
				else if ( level.script == "zombie_cod5_sumpf" && doors[i].target == "attic_blocker" )
					continue;
				else
				{
					doors[i] notify( "trigger", get_players()[0], true );
				}
				wait( 0.05 );
			}

			debris = getentarray( "zombie_debris", "targetname" );
			for ( i = 0; i < debris.size; i++ )
			{
				if ( level.script == "zombie_cod5_factory" && i == 1 )
					continue;
				else if ( level.script == "zombie_cod5_asylum" && debris[i].target == "north_upstairs_blocker" )
					continue;
				else if ( level.script == "zombie_cod5_sumpf" && debris[i].target == "upstairs_blocker" )
					continue;
				else 
				{			
					if ( level.script == "zombie_temple" )
						wait( 0.05 );
					debris[i] notify( "trigger", get_players()[0], true );
				}
				wait( 0.05 );
			}	
			break;
		}
		wait 0.1;
	}
}

//custom function to get non destroyed chunks ( includes all window types )
custom_get_non_destroyed_chunks( barrier_chunks )
{

	array = [];

	for( i = 0; i < barrier_chunks.size; i++ )
	{

		if( barrier_chunks[i] get_chunk_state() == "repaired" )
		{
			if (IsDefined (barrier_chunks[i].script_parameters) && barrier_chunks[i].script_parameters == "board")
			{			
				if( barrier_chunks[i].origin == barrier_chunks[i].og_origin ) 
					{
						array[array.size] = barrier_chunks[i]; 
					}
			}
			else if (IsDefined (barrier_chunks[i].script_parameters) && barrier_chunks[i].script_parameters == "repair_board" || barrier_chunks[i].script_parameters == "barricade_vents")
			{			
				if( barrier_chunks[i].origin == barrier_chunks[i].og_origin ) 
				{
					array[array.size] = barrier_chunks[i]; 
				}
			}
			else if (IsDefined (barrier_chunks[i].script_parameters) && (barrier_chunks[i].script_parameters == "bar") )
			{
				if( barrier_chunks[i].origin == barrier_chunks[i].og_origin ) 
				{
					array[array.size] = barrier_chunks[i];
				}
			}	
			
			else if (IsDefined (barrier_chunks[i].script_parameters) && (barrier_chunks[i].script_parameters == "grate") )
			{
				return undefined;
				//array[array.size] = barrier_chunks[i];
			}	
		}

	}

	if (array.size == 0)
		return undefined;
	
	return array;

}

open_windows()
{	
	if( getDvar( "open_windows" ) == "" )
		setDvar( "open_windows", 1 );

	while(1)
	{
		if( getDvarInt( "open_windows" ) == 1 )
		{
			window_boards = getstructarray( "exterior_goal", "targetname" );

			for ( i = 0; i < window_boards.size; i++ )
			{
				thread clearwindow(window_boards[i]);
				wait(0.05);
			}
			break;
		}
		wait 0.1;
	}
}

clearwindow(window)
{

	if ( !all_chunks_destroyed(window.barrier_chunks) )
	{
		chunks = custom_get_non_destroyed_chunks( window.barrier_chunks ); 
		for ( j = 0; j < chunks.size; j++ )
		{
			
			window thread maps\_zombiemode_blockers::remove_chunk( chunks[j], window, true );
			wait_network_frame();
			wait(0.05);

		}
			
		if (all_chunks_destroyed(window.barrier_chunks))
		{

			if (IsDefined(window.clip))
			{

				window.clip ConnectPaths();
				wait( 0.05 ); 
				window.clip disable_trigger();  

			}
			else
			{
				for( k = 0; k < window.barrier_chunks.size; k++ )
				{
					window.barrier_chunks[k] ConnectPaths(); 
				}
			}
		}

		wait_network_frame();	

	}

}

checkforboxhit()
{

	while ( true )
	{

		self waittill( "trigger" );
		level.box_hits++;
		self waittill( "chest_accessed" );

	}

}

checkfortraphit( trap )
{

	if ( trap == 0 ) //wuen
	{

		while ( true )
		{

			self waittill( "trigger" );
			if ( level.wuen == 0)
				level.trap_hits++;
			level.wuen = 1;
			self waittill( "available" );
			level.wuen = 0;

		}

	}
	else if ( trap == 1 ) //warehouse
	{

		while ( true )
		{

			self waittill( "trigger" );
			if ( level.ware == 0)
				level.trap_hits++;
			level.ware = 1;
			self waittill( "available" );
			level.ware = 0;

		}

	}
	else if ( trap == 2 ) //bridge
	{

		while ( true )
		{

			self waittill( "trigger" );
			if ( level.bridge == 0)
				level.trap_hits++;
			level.bridge = 1;
			self waittill( "available" );
			level.bridge = 0;

		}

	}

}

theater_disable_crawlers( spawner )
{

	if ( spawner.script_noteworthy == "quad_zombie_spawner" )
	{

		return true;

	}

}

// turns on power and activates things around the map
turn_on_power()
{	
	if( getDvar( "turn_power_on" ) == "" )
		setDvar( "turn_power_on", 1 );
	level waittill( "fade_introblack" );

	while(1)
	{
		if ( getDvarInt( "turn_power_on" ) == 1 )
		{
			if ( level.script == "zombie_theater" )
			{

				level.ignore_spawner_func = ::theater_disable_crawlers;
				trig = getent("use_elec_switch","targetname");
				trig notify( "trigger" );

			}	
			else if ( level.script == "zombie_pentagon" )
			{

				trig = getent("use_elec_switch","targetname");
				trig notify( "trigger" );

				wait ( 5 );
				level.next_thief_round = 1;

			}	
			else if ( level.script == "zombie_cosmodrome" )
			{

				trig = getent( "use_elec_switch" , "targetname" );
				trig notify( "trigger" );

				// open up pack a punch
				upper_door_model = GetEnt( "rocket_room_top_door", "targetname" );
				upper_door_model.clip = GetEnt( upper_door_model.target, "targetname" );
				upper_door_model.clip LinkTo( upper_door_model ); 
			
				upper_door_model MoveTo(upper_door_model.origin + upper_door_model.script_vector, 1.5 );
				level.pack_a_punch_door MoveTo( level.pack_a_punch_door.origin + level.pack_a_punch_door.script_vector, 1.5 );
				level.pack_a_punch_door.clip NotSolid();
				level.pack_a_punch_door waittill( "movedone" );
				level.pack_a_punch_door.clip ConnectPaths();

				flag_set( "rocket_group" );

			}
			else if ( level.script == "zombie_coast" )
			{

				trig = getent("use_elec_switch","targetname");
				trig notify( "trigger" );

			}
			else if ( level.script == "zombie_temple" )
			{

				flag_set("left_switch_done");
				flag_set("right_switch_done");

			}
			else if ( level.script == "zombie_moon" )
			{

				trig = getent("use_elec_switch","targetname");
				trig notify( "trigger" );

			}
			else if ( level.script == "zombie_cod5_asylum" )
			{

				trig = getent("use_master_switch","targetname");
				trig notify( "trigger" );

			}
			else if ( level.script == "zombie_cod5_sumpf" )
			{

				// activate zipline
				zipPowerTrigger = getent("zip_lever_trigger", "targetname");
				zipPowerTrigger notify( "trigger" );

			}
			else if ( level.script == "zombie_cod5_factory" )
			{

				trig = getent( "use_power_switch", "targetname" );
				trig notify( "trigger" );

				// link teleporters
				trigger = getent( "trigger_teleport_core", "targetname" );
				wait 0.5;
				for ( i = 0; i < 3; i++ )
				{
					while ( level.is_cooldown )
					{
						wait( 0.05 );
					}

					level.teleporter_pad_trig[ i ] notify( "trigger" );
					wait( 0.05 );
					trigger notify( "trigger" );
				}
			}
			break;
		}
		wait 0.1;
	}
}

watch_for_trade()
{

	has_weapon = false;
	level.trades = 0;

	pap = GetEnt("zombie_vending_upgrade", "targetname");

	if ( level.script == "zombie_cod5_factory" )
	{

		while ( true )
		{

			if ( self maps\_zombiemode_weapons::has_weapon_or_upgrade( "tesla_gun_zm" ))
			{

				if ( !has_weapon )
				{

					level.trades++;

				}

				has_weapon = true;

			}

			wait ( 0.5 );

			if ( !self maps\_zombiemode_weapons::has_weapon_or_upgrade ( "tesla_gun_zm" ) && pap.current_weapon == "")
			{

				has_weapon = false;

			}

		}

	}
	else if ( level.script == "zombie_temple" )
	{

		while ( true )
		{

			if ( self maps\_zombiemode_weapons::has_weapon_or_upgrade ( "shrink_ray_zm" ) )
			{

				if ( !has_weapon )
				{

					level.trades++;

				}

				has_weapon = true;

			}

			wait ( 0.5 );

			if ( !self maps\_zombiemode_weapons::has_weapon_or_upgrade ( "shrink_ray_zm" ) )
			{

				has_weapon = false;

			}

		}

	}
	else if ( level.script == "zombie_cosmodrome" )
	{

		while ( true )
		{

			if ( self maps\_zombiemode_weapons::has_weapon_or_upgrade ( "thundergun_zm" ) )
			{

				if ( !has_weapon )
				{

					level.trades++;

				}

				has_weapon = true;

			}

			wait ( 0.5 );

			if ( !self maps\_zombiemode_weapons::has_weapon_or_upgrade ( "thundergun_zm" ) )
			{

				has_weapon = false;

			}

		}

	}

}

give_player_weapons()
{	
	level waittill( "fade_introblack" );

	switch ( Tolower( GetDvar( #"mapname" ) ) ) 
	{
	case "zombie_cod5_prototype":
		self takeWeapon( "m1911_zm" );
		self giveWeapon( "thundergun_zm" );
		self giveWeapon( "ray_gun_zm" );
		self switchToWeapon( "thundergun_zm");
		self maps\_zombiemode_weap_cymbal_monkey::player_give_cymbal_monkey();
		break;

	case "zombie_cod5_asylum":
		self takeweapon( "m1911_zm" );
		self giveWeapon( "cz75dw_zm" );
		self giveWeapon( "ray_gun_zm" );
		self switchToWeapon( "cz75dw_zm");
		self maps\_zombiemode_weap_cymbal_monkey::player_give_cymbal_monkey();
		break;

	case "zombie_cod5_sumpf":
		self takeWeapon( "m1911_zm" );
		self giveWeapon( "tesla_gun_zm" );
		self giveWeapon( "cz75dw_zm" );
		self switchToWeapon( "tesla_gun_zm");
		self maps\_zombiemode_weap_cymbal_monkey::player_give_cymbal_monkey();
		// if(isDefined(level.additional_primaryweaponmachine_origin))
		// 	self giveWeapon( "ray_gun_zm" );}
		break;

	case "zombie_cod5_factory":
		self takeWeapon( "m1911_zm" );
		self giveWeapon( "bowie_knife_zm" );
		self giveWeapon( "tesla_gun_upgraded_zm", 0, self maps\_zombiemode_weapons::get_pack_a_punch_weapon_options( "tesla_gun_upgraded_zm" ) );
		self giveWeapon( "ray_gun_upgraded_zm", 0, self maps\_zombiemode_weapons::get_pack_a_punch_weapon_options( "ray_gun_upgraded_zm" ) );
		self switchToWeapon( "tesla_gun_upgraded_zm");
		self maps\_zombiemode_weap_cymbal_monkey::player_give_cymbal_monkey();
		// if(isDefined(level.additional_primaryweaponmachine_origin))
		// 	self giveWeapon( "m1911_upgraded_zm", 0, player maps\_zombiemode_weapons::get_pack_a_punch_weapon_options( "m1911_upgraded_zm" ) );
		break;

	case "zombie_theater":
		self takeWeapon( "m1911_zm" );
		self giveWeapon( "bowie_knife_zm" );
		self giveWeapon( "thundergun_zm" );
		self giveWeapon( "ray_gun_zm" );
		self switchToWeapon( "thundergun_zm");
		self maps\_zombiemode_weap_cymbal_monkey::player_give_cymbal_monkey();
			break;

	case "zombie_pentagon":
		self takeWeapon( "m1911_zm" );
		self giveWeapon( "bowie_knife_zm" );
		self giveWeapon( "crossbow_explosive_upgraded_zm", 0, self maps\_zombiemode_weapons::get_pack_a_punch_weapon_options( "crossbow_explosive_upgraded_zm" ) );	
		self giveWeapon( "ray_gun_upgraded_zm", 0, self maps\_zombiemode_weapons::get_pack_a_punch_weapon_options( "ray_gun_upgraded_zm" ) );
		self switchToWeapon( "crossbow_explosive_upgraded_zm");
		self maps\_zombiemode_weap_cymbal_monkey::player_give_cymbal_monkey();
		break;	

	case "zombie_cosmodrome":
		self takeWeapon( "m1911_zm" );
		self giveWeapon( "thundergun_upgraded_zm", 0, self maps\_zombiemode_weapons::get_pack_a_punch_weapon_options( "thundergun_upgraded_zm" ) );
		self giveWeapon( "ray_gun_upgraded_zm", 0, self maps\_zombiemode_weapons::get_pack_a_punch_weapon_options( "ray_gun_upgraded_zm" ) );
		self switchToWeapon( "thundergun_upgraded_zm");
		self maps\_zombiemode_weap_black_hole_bomb::player_give_black_hole_bomb();
		break;

	case "zombie_coast":
		self takeWeapon( "m1911_zm" );
		self giveWeapon( "sniper_explosive_upgraded_zm", 0, self maps\_zombiemode_weapons::get_pack_a_punch_weapon_options( "sniper_explosive_upgraded_zm" ) );
		self giveWeapon( "humangun_upgraded_zm", 0, self maps\_zombiemode_weapons::get_pack_a_punch_weapon_options( "humangun_upgraded_zm" ) );
		self switchToWeapon( "sniper_explosive_upgraded_zm");
		//self giveWeapon( "ray_gun_upgraded_zm", 0, player maps\_zombiemode_weapons::get_pack_a_punch_weapon_options( "ray_gun_upgraded_zm" ) );
		self maps\_zombiemode_weap_nesting_dolls::player_give_nesting_dolls();
		break;

	case "zombie_temple":
		self takeWeapon( "m1911_zm" );
		self giveWeapon( "bowie_knife_zm" );
		self giveWeapon( "shrink_ray_upgraded_zm", 0, self maps\_zombiemode_weapons::get_pack_a_punch_weapon_options( "shrink_ray_upgraded_zm" ) );
		self giveWeapon( "m1911_upgraded_zm", 0, self maps\_zombiemode_weapons::get_pack_a_punch_weapon_options( "m1911_upgraded_zm" ) );
		self switchToWeapon( "shrink_ray_upgraded_zm");
		self maps\_zombiemode_weap_cymbal_monkey::player_give_cymbal_monkey();
		break;

	case "zombie_moon":
		self takeWeapon( "m1911_zm" );
		self giveWeapon( "bowie_knife_zm" );
		self giveWeapon( "microwavegun_upgraded_zm", 0, self maps\_zombiemode_weapons::get_pack_a_punch_weapon_options( "microwavegun_upgraded_zm" ) );
		self giveWeapon( "m1911_upgraded_zm", 0, self maps\_zombiemode_weapons::get_pack_a_punch_weapon_options( "m1911_upgraded_zm" ) );
		self switchToWeapon( "microwavegun_upgraded_zm");
		self maps\_zombiemode_weap_black_hole_bomb::player_give_black_hole_bomb();
		break;
	}
}

give_player_perks()
{	
	if ( getDvar( "player_perk_1") == "" && getDvar( "player_perk_2") == "" && getDvar( "player_perk_3") == "" && getDvar( "player_perk_4") == "" && getDvar( "player_perk_5") == "" && getDvar( "player_perk_6") == "" )
	{	
		switch ( Tolower( GetDvar( #"mapname" ) ) ) 
		{
		case "zombie_cod5_prototype":

			break;

		case "zombie_cod5_asylum":
			self maps\_zombiemode_perks::give_perk( "specialty_fastreload", true );
			self maps\_zombiemode_perks::give_perk( "specialty_rof", true );
			self maps\_zombiemode_perks::give_perk( "specialty_armorvest", true );
			self maps\_zombiemode_perks::give_perk( "specialty_quickrevive", true );
			break;

		case "zombie_cod5_sumpf":
			self maps\_zombiemode_perks::give_perk( "specialty_quickrevive", true );
			self maps\_zombiemode_perks::give_perk( "specialty_fastreload", true );
			if(isDefined(level.zombie_additionalprimaryweapon_machine_origin)) {
				self maps\_zombiemode_perks::give_perk( "specialty_additionalprimaryweapon", true );
			}
			self maps\_zombiemode_perks::give_perk( "specialty_armorvest", true );
			break;

		case "zombie_cod5_factory":
			self maps\_zombiemode_perks::give_perk( "specialty_fastreload", true );
			if(isDefined(level.zombie_additionalprimaryweapon_machine_origin)) {
				self maps\_zombiemode_perks::give_perk( "specialty_additionalprimaryweapon", true );
			}
			self maps\_zombiemode_perks::give_perk( "specialty_armorvest", true );
			self maps\_zombiemode_perks::give_perk( "specialty_quickrevive", true );
			break;

		case "zombie_theater":
			self maps\_zombiemode_perks::give_perk( "specialty_quickrevive", true );
			self maps\_zombiemode_perks::give_perk( "specialty_fastreload", true );
			self maps\_zombiemode_perks::give_perk( "specialty_armorvest", true );
			break;

		case "zombie_pentagon":
			self maps\_zombiemode_perks::give_perk( "specialty_quickrevive", true );
			self maps\_zombiemode_perks::give_perk( "specialty_fastreload", true );
			if(isDefined(level.zombie_additionalprimaryweapon_machine_origin)) {
				self maps\_zombiemode_perks::give_perk( "specialty_additionalprimaryweapon", true );
			}else{
				self maps\_zombiemode_perks::give_perk( "specialty_rof", true );
			}
			self maps\_zombiemode_perks::give_perk( "specialty_armorvest", true );
			break;	

		case "zombie_cosmodrome":
			self maps\_zombiemode_perks::give_perk( "specialty_quickrevive", true );
			self maps\_zombiemode_perks::give_perk( "specialty_flakjacket", true );
			self maps\_zombiemode_perks::give_perk( "specialty_fastreload", true );
			if(isDefined(level.zombie_additionalprimaryweapon_machine_origin)) {
				self maps\_zombiemode_perks::give_perk( "specialty_additionalprimaryweapon", true );
			}

			self maps\_zombiemode_perks::give_perk( "specialty_armorvest", true );
			self maps\_zombiemode_perks::give_perk( "specialty_longersprint", true );
			break;

		case "zombie_coast":
			self maps\_zombiemode_perks::give_perk( "specialty_quickrevive", true );
			self maps\_zombiemode_perks::give_perk( "specialty_flakjacket", true );
			self maps\_zombiemode_perks::give_perk( "specialty_fastreload", true );
			if(isDefined(level.zombie_additionalprimaryweapon_machine_origin)) {
				self maps\_zombiemode_perks::give_perk( "specialty_additionalprimaryweapon", true );
			}
			self maps\_zombiemode_perks::give_perk( "specialty_armorvest", true );
			self maps\_zombiemode_perks::give_perk( "specialty_longersprint", true );
			self maps\_zombiemode_perks::give_perk( "specialty_rof", true );
			self maps\_zombiemode_perks::give_perk( "specialty_deadshot", true );
		break;

		case "zombie_temple":
			self maps\_zombiemode_perks::give_perk( "specialty_quickrevive", true );
			self maps\_zombiemode_perks::give_perk( "specialty_flakjacket", true );
			self maps\_zombiemode_perks::give_perk( "specialty_fastreload", true );

			if(isDefined(level.zombie_additionalprimaryweapon_machine_origin)) {
				self maps\_zombiemode_perks::give_perk( "specialty_additionalprimaryweapon", true );
			}
			
			self maps\_zombiemode_perks::give_perk( "specialty_armorvest", true );
			self maps\_zombiemode_perks::give_perk( "specialty_longersprint", true );
			self maps\_zombiemode_perks::give_perk( "specialty_rof", true );
			self maps\_zombiemode_perks::give_perk( "specialty_deadshot", true );
			break;

		case "zombie_moon":
			self maps\_zombiemode_perks::give_perk( "specialty_quickrevive", true );
			self maps\_zombiemode_perks::give_perk( "specialty_flakjacket", true );
			self maps\_zombiemode_perks::give_perk( "specialty_fastreload", true );
			if(isDefined(level.zombie_additionalprimaryweapon_machine_origin)) {
				self maps\_zombiemode_perks::give_perk( "specialty_additionalprimaryweapon", true );
			}
			self maps\_zombiemode_perks::give_perk( "specialty_armorvest", true );
			self maps\_zombiemode_perks::give_perk( "specialty_longersprint", true );
			self maps\_zombiemode_perks::give_perk( "specialty_rof", true );
			self maps\_zombiemode_perks::give_perk( "specialty_deadshot", true );
			break;
		}
	}
	else
	{
		self maps\_zombiemode_perks::give_perk( getDvar( "player_perk_1"), true );
		self maps\_zombiemode_perks::give_perk( getDvar( "player_perk_2"), true );
		self maps\_zombiemode_perks::give_perk( getDvar( "player_perk_3"), true );
		self maps\_zombiemode_perks::give_perk( getDvar( "player_perk_4"), true );
		self maps\_zombiemode_perks::give_perk( getDvar( "player_perk_5"), true );
		self maps\_zombiemode_perks::give_perk( getDvar( "player_perk_6"), true );
	}
}

set_player_weapon()
{	
	level waittill( "fade_introblack" );
	prev_weapon = "";

	while(1)
	{	
		wait 0.05;
		weapon = getDvar( "weapon_to_give" );
		if( weapon == "" )
			continue;
		if( weapon == prev_weapon )
			continue;

		self maps\_zombiemode_weapons::weapon_give( weapon );
		prev_weapon = weapon;
	}

}

hud_sph()
{
	level endon("end_game");
    level waittill ( "start_of_round" );
	
	while(1)
	{
		zombies_thus_far = level.global_zombies_killed_round;
		hordes = zombies_thus_far / 24;
		current_time = int(gettime() / 1000) - level.current_round_start_time;
		if( level.zombie_total + get_enemy_count() == 0 )
			current_time = level.current_round_end_time - level.current_round_start_time;
		level.round_seconds_per_horde = int(current_time / hordes * 100) / 100;
		self setClientDvar("hud_sph", level.round_seconds_per_horde);

		wait 1;
	}
}

trade_hud()
{

	level endon("end_game");

	tradehud = NewHudElem();
	tradehud.horzAlign = "center";
	tradehud.vertAlign = "top";
	tradehud.alignX = "middle";
	tradehud.alignY = "top";
	tradehud.fontScale = 1.3;
	tradehud.alpha = 1;
	tradehud.hidewheninmenu = 0;
	tradehud.foreground = 1;
	tradehud.color = ( 1.0, 1.0, 1.0 );	

	tradehud.x -= 50;
	tradehud.y += 2;
	tradehud.label = "Trade Average: ";
	tradehud setValue( 0 );
	trade = 0;

	while(1)
	{

		if(tradehud.alpha != 1)
		{
			tradehud.alpha = 1;
		}

		if ( trade != level.trades )
		{

			tradehud setValue( level.box_hits / level.trades );
			trade = level.trades;

		}
		wait 0.05;

	}

}

bo_hud()
{

	level endon("end_game");

	box_hud = NewHudElem();
	box_hud.horzAlign = "center";
	box_hud.vertAlign = "top";
	box_hud.alignX = "left";
	box_hud.alignY = "middle";
	box_hud.y += 2;
	box_hud.fontScale = 1.3;
	box_hud.alpha = 1;
	box_hud.hidewheninmenu = 0;
	box_hud.foreground = 1;
	box_hud.color = ( 1.0, 1.0, 1.0 );	

	box_hud.y += 2;
	box_hud.x += 5;
	box_hud.label = "";
	box_hud setValue( level.box_hits );

	while(1)
	{

		if(box_hud.alpha != 1)
		{
			box_hud.alpha = 1;
		}

		box_hud setValue( level.box_hits );
		wait 0.05;

	}

}

tra_hud()
{

	level endon("end_game");

	trap_hud = NewHudElem();
	trap_hud.horzAlign = "center";
	trap_hud.vertAlign = "top";
	trap_hud.alignX = "left";
	trap_hud.alignY = "middle";
	trap_hud.y += 2;
	trap_hud.fontScale = 1.3;
	trap_hud.alpha = 1;
	trap_hud.hidewheninmenu = 0;
	trap_hud.foreground = 1;
	trap_hud.color = ( 1.0, 1.0, 1.0 );	

	trap_hud.y += 20;
	trap_hud.x += 5;
	trap_hud.label = "";
	trap_hud setValue( level.trap_hits );

	while(1)
	{

		if(trap_hud.alpha != 1)
		{
			trap_hud.alpha = 1;
		}
		
		trap_hud setValue( level.trap_hits );
		wait 0.05;

	}

}

enable_traps_five()
{
	level waittill( "fade_introblack" );
	traps_array = getentarray( "trigger_battery_trap_fix", "targetname" );
	
	for ( i = 0; i < traps_array.size; i++ )
	{

		get_players()[0]._trap_piece = 1;
		traps_array[i] build_trap();

	}

}

build_trap()
{

	self notify( "trigger", get_players()[0] );
	wait( 1 );

}

hud_health_bar()
{
	self endon("disconnect");
	self endon("end_game");

	width = 113;
	height = 7;

	barElemBackround = create_hud( "left", "bottom");
	barElemBackround.x = 0;
	barElemBackround.y = -100;
	barElemBackround.width = width + 2;
	barElemBackround.height = height + 2;
	barElemBackround.foreground = 0;
	barElemBackround.shader = "black";
	barElemBackround setShader( "black", width + 2, height + 2 );

	barElem = create_hud( "left", "bottom");
	barElem.x = 1;
	barElem.y = -101;
	barElem.width = width;
	barElem.height = height;
	barElem.foreground = 1;
	barElem.shader = "white";
	barElem setShader( "white", width, height );

	health_text = create_hud( "left", "bottom");
	health_text.x = 49;
	health_text.y = -107;
	health_text.fontScale = 1.3;

	while (1)
	{
		if( getDvarInt( "hud_health_bar" ) == 0 )
		{	
			if(barElem.alpha != 0)
			{
				barElem.alpha = 0;
				barElemBackround.alpha = 0;
				health_text.alpha = 0;
			}
		}
		else
		{
			barElem updateHealth(self.health / self.maxhealth);
			health_text setValue(self.health);

			if( is_true( self.waiting_to_revive ) || self maps\_laststand::player_is_in_laststand() )
			{
				barElem.alpha = 0;
				barElemBackround.alpha = 0;
				health_text.alpha = 0;

				wait 0.05;
				continue;
			}

			if ( health_text.alpha != 0.8 )
	        {
	            barElem.alpha = 0.75;
	            barElemBackround.alpha = 0.75;
				health_text.alpha = 0.8;
	        }
    	}
		wait 0.05;
	}
}

updateHealth( barFrac )
{
	barWidth = int(self.width * barFrac);
	self setShader( self.shader, barWidth, self.height );
}

create_hud( side, top )
{
	hud = NewClientHudElem( self );
	hud.horzAlign = side;
	hud.vertAlign = top;
	hud.alignX = side;
	hud.alignY = top;
	hud.alpha = 0;
	hud.fontscale = 1.3;
	hud.color = ( 1.0, 1.0, 1.0 );
	hud.hidewheninmenu = 1;

	return hud;
}

hud_game_time() {

	level waittill("fade_introblack");

	level thread game_time();
	level thread round_time();
}

game_time() {
	//GameTime

	level endon("intermission");

	level.total_time = 3600;

	while(1) {
		level.total_time++;
		
		update_time(level.total_time, "hud_total_time");

		wait 1;
	}
}

update_time(time, timer) {
	players = get_players();
	for(i = 0; i < players.size; i++) {
		players[i] setClientDvar(timer, seconds_to_string(time));
	}
}

	



round_time() {

	level.round_time = 0;

	level thread round_time_watcher();

	while(1) {
		level.round_time++;
		update_time(level.round_time, "hud_round_time");
		wait(1);
	}
}

round_time_watcher(roundTime) {

	level endon("end_game");

	while(1) {
		level waittill("start_of_round");
		level.round_time = 0;
		wait(1);
	}


}

hud_zombies_stats() {
	//level thread hud_zombies_health();
	//level thread hud_zombies_remaining();
	//level thread hud_zombies_speed();
}

hud_zombies_remaining() {
	while(1)
	{
		zombs = level.zombie_total + get_enemy_count();

		if( zombs == 0 || is_true(flag("enter_nml")) || is_true(flag("round_restarting")) )
		{
			if(GetDvar("hud_enemy_counter_value") != "0")
			{
				self SetClientDvar("hud_enemy_counter_value", "0");
			}
		}
		else
		{
			if(GetDvarInt("hud_enemy_counter_value") != zombs)
			{
				self SetClientDvar("hud_enemy_counter_value", zombs);
			}
		}

		wait 0.05;
	}
}

// checks if player has set insta kill rounds and changes zombie helf accordingly
insta_kill_rounds()
{

	while (true)
	{

		// set insta kill round if not already set
		if (getDvarInt("round_insta") == 1 && level.zombie_health != -50)
		{

			level.zombie_health = -50;

			// set zombie health for all currently alive zombies
			zombies = GetAiArray( "axis" );
			for (i = 0; i < zombies.size; i++)
			{

				zombies[i].health = 150;

			}

		}
		else if (getDvarInt("round_insta") == 0 && level.zombie_health == -50)
		{

			ai_calculate_health( level.round_number );
			// set zombie health back to normal for all currently alive zombies
			zombies = GetAiArray( "axis" );
			for (i = 0; i < zombies.size; i++)
			{

				zombies[i].health = level.zombie_health;

			}

		}

		wait 1;

	}

}

seconds_to_string(seconds) {
	hours = int(seconds / 3600);
	minutes = int((seconds - (hours * 3600)) / 60);
	seconds = seconds % 60;

	if(seconds < 10) {
		seconds = "0" + seconds;
	}

	if(minutes < 10 && hours >= 1) {
		minutes = "0" + minutes;
	}

	time = "";

	if(hours > 0) {
		time = hours + ":";
	}
		time += minutes + ":" + seconds;

	return time;
}

get_doors_nearby()
{
	flag_wait( "all_players_spawned" );

    players = get_players();

    while(1)
    {
        zombie_doors = GetEntArray( "zombie_door", "targetname" );
		debris = getentarray( "zombie_debris", "targetname" );
		//targets = GetEntArray( self.target, "targetname" );
        for( i = 0; i < zombie_doors.size; i++ )
        {
        	//zombie_doors[i] notify("trigger", players[0]);
            if (Distance(zombie_doors[i].origin, players[0].origin) < 128)
            {
               	iprintln(zombie_doors[i].target);
               	//iprintln(zombie_doors[i].origin);
               	wait 0.5;
            }

			
            //iprintln(zombie_doors[i].target);
        }
		for( i = 0; i < debris.size; i++ )
        {
		if (Distance(debris[i].origin, players[0].origin) < 128)
            {
               	iprintln(debris[i].target);
               	//iprintln(debris[i].origin);
               	wait 0.5;
            }
		}
        wait 0.05;
    }
}

disable_powerup()
{	
	if( getDvar( "disable_powerups" ) == "")
		setDvar( "disable_powerups", false );
	while(1)
	{	
		powerups = getDvar( "disable_powerups" );
		if ( powerups )
			level.mutators["mutator_noPowerups"] = true;
		else
			level.mutators["mutator_noPowerups"] = false;
		
		wait 0.1;
	}
}

disable_special_zombies()
{	
	flag_wait( "all_players_spawned" );
	if( level.script == "zombie_temple" )
	{	
		for( i = 0; i < level.napalm_zombie_spawners.size; i++)
		{
			level.napalm_zombie_spawners[i] = "";
		}
		for( i = 0; i < level.sonic_zombie_spawners.size; i++)
		{
			level.sonic_zombie_spawners[i] = "";
		}
	}
}

zone_hud()
{
	self endon("disconnect");

	current_name = " ";

	while(1)
	{
		wait_network_frame();

		name = choose_zone_name(self get_current_zone(), current_name);

		if(current_name == name)
		{
			continue;
		}

		current_name = name;

		self send_message_to_csc("hud_anim_handler", "hud_zone_name_out");
		wait .25;
		self SetClientDvar("hud_zone_name", name);
		self send_message_to_csc("hud_anim_handler", "hud_zone_name_in");
	}
}

choose_zone_name(zone, current_name)
{
	if(self.sessionstate == "spectator")
	{
		zone = undefined;
	}

	if(IsDefined(zone))
	{
		if(level.script == "zombie_pentagon")
		{
			if(zone == "labs_elevator")
			{
				zone = "war_room_zone_elevator";
			}
		}
		else if(level.script == "zombie_cosmodrome")
		{
			if(IsDefined(self.lander) && self.lander)
			{
				zone = undefined;
			}
		}
		else if(level.script == "zombie_coast")
		{
			if(IsDefined(self.is_ziplining) && self.is_ziplining)
			{
				zone = undefined;
			}
		}
		else if(level.script == "zombie_temple")
		{
			if(zone == "waterfall_tunnel_a_zone")
			{
				zone = "waterfall_tunnel_zone";
			}
		}
		else if(level.script == "zombie_moon")
		{
			if(IsSubStr(zone, "airlock"))
			{
				return current_name;
			}
		}
	}

	name = " ";

	if(IsDefined(zone))
	{
		name = "reimagined_" + level.script + "_" + zone;
	}

	return name;
}

send_message_to_csc(name, message)
{
	csc_message = name + ":" + message;

	if(isdefined(self) && IsPlayer(self))
		setClientSysState("client_systems", csc_message, self);
	else
	{
		players = get_players();

		for(i = 0; i < players.size; i++)
		{
			setClientSysState("client_systems", csc_message, players[i]);
		}
	}
}

health_bar_hud()
{
	health_bar_width_max = 110;

	while (1)
	{
		health_ratio = self.health / self.maxhealth;

		self SetClientDvar("hud_health_bar_value", self.health);
		self SetClientDvar("hud_health_bar_width", health_bar_width_max * health_ratio);

		wait 0.05;
	}
}