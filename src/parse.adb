-- WORDS, a Latin dictionary, by Colonel William Whitaker (USAF, Retired)
--
-- Copyright William A. Whitaker (1936–2010)
--
-- This is a free program, which means it is proper to copy it and pass
-- it on to your friends. Consider it a developmental item for which
-- there is no charge. However, just for form, it is Copyrighted
-- (c). Permission is hereby freely given for any and all use of program
-- and data. You can sell it as your own, but at least tell me.
-- 
-- This version is distributed without obligation, but the developer
-- would appreciate comments and suggestions.
-- 
-- All parts of the WORDS system, source code and data files, are made freely
-- available to anyone who wishes to use them, for whatever purpose.

with text_io;
with strings_package; use strings_package;
with latin_file_names; use latin_file_names;
with word_parameters; use word_parameters;
with developer_parameters; use developer_parameters;
with inflections_package; use inflections_package;
with dictionary_package; use dictionary_package;
with addons_package; use addons_package;
with word_support_package; use word_support_package;
with preface;
with word_package; use word_package;
with list_package; use list_package;
with tricks_package; use tricks_package;
with config; use config;
with preface;
with put_stat;
with english_support_package; use english_support_package;
with search_english;
pragma elaborate(word_parameters);
procedure parse(command_line : string := "") is
   use inflections_package.integer_io;
   use inflection_record_io;
   use text_io;

   storage_error_count : integer := 0;

   j, k, l : integer := 0;
   line, blank_line : string(1..2500) := (others => ' ');
   --INPUT : TEXT_IO.FILE_TYPE;

   pa : parse_array(1..100) := (others => null_parse_record);
   syncope_max : constant := 20;
   no_syncope : boolean := false;
   tricks_max : constant := 40;
   sypa : parse_array(1..syncope_max) := (others => null_parse_record);
   trpa : parse_array(1..tricks_max) := (others => null_parse_record);
   pa_last, sypa_last, trpa_last : integer := 0;

   procedure parse_line(input_line : string) is
	  l : integer := trim(input_line)'last;
	  --LINE : STRING(1..2500) := (others => ' ');
	  w : string(1..l) := (others => ' ');
   begin
	  word_number := 0;
	  line(1..l) := trim(input_line);

	  --  Someday I ought to be interested in punctuation and numbers, but not now
	  eliminate_not_letters:
		  begin
			 for i in 1..l  loop
				if ((line(i) in 'A'..'Z')  or
					  (line(i) = '-')           or     --  For the comment
					  (line(i) = '.')           or     --  Catch period later
					  (line(i) in 'a'..'z'))  then
				   null;
				else
				   line(i) := ' ';
				end if;
			 end loop;
		  end eliminate_not_letters;

		  j := 1;
		  k := 0;
	  over_line:
		  while j <= l  loop

			 --  Skip over leading and intervening blanks, looking for comments
			 --  Punctuation, numbers, and special characters were cleared above
			 for i in k+1..l  loop
				exit when line(j) in 'A'..'Z';
				exit when line(j) in 'a'..'z';
				if i < l  and then
				  line(i..i+1) = "--"   then
				   exit over_line;      --  the rest of the line is comment
				end if;
				j := i + 1;
			 end loop;

			 exit when j > l;             --  Kludge

			 follows_period := false;
			 if followed_by_period  then
				followed_by_period := false;
				follows_period := true;
			 end if;

			 capitalized := false;
			 all_caps := false;

			 --  Extract the word
			 for i in j..l  loop

				--  Although I have removed punctuation above, it may not always be so
				if line(i) = '.'  then
				   followed_by_period := true;
				   exit;
				end if;
				--         exit when (LINE(I) = ' ' or LINE(I) = ',' or LINE(I) = '-'
				--                or LINE(I) = ';' or LINE(I) = ':'
				--                or LINE(I) = '(' or LINE(I) = '[' or LINE(I) = '{' or LINE(I) = '<'
				--                or LINE(I) = ')' or LINE(I) = ']' or LINE(I) = '}' or LINE(I) = '>'
				--                or (CHARACTER'POS(LINE(I)) < 32)  or (CHARACTER'POS(LINE(I)) > 127) );
				exit when ((line(i) not in 'A'..'Z') and (line(i) not in 'a'..'z'));
				w(i) := line(i);
				k := i;

			 end loop;

			 if w(j) in 'A'..'Z'  and then
			   k - j >= 1  and then
			   w(j+1) in 'a'..'z'  then
				capitalized := true;
			 end if;

			 all_caps := true;
			 for i in j..k  loop
				if w(i) = lower_case(w(i))  then
				   all_caps := false;
				   exit;
				end if;
			 end loop;

			 for i in j..k-1  loop               --  Kludge for QVAE
				if w(i) = 'Q'  and then w(i+1) = 'V'  then
				   w(i+1) := 'U';
				end if;
			 end loop;

			 if language = english_to_latin  then

			parse_line_english_to_latin:
				--  Since we do only one English word per line
				declare
				   input_word : constant string := w(j..k);
				   pofs : part_of_speech_type := x;
				begin

				   --  Extract from the rest of the line
				   --  Should do AUX here !!!!!!!!!!!!!!!!!!!!!!!!
				   extract_pofs:
					   begin
						  part_of_speech_type_io.get(line(k+1..l), pofs, l);
						  --TEXT_IO.PUT_LINE("In EXTRACT   " & LINE(K+1..L));
					   exception
						  when others =>
							 pofs := x;
					   end extract_pofs;
					   --PART_OF_SPEECH_TYPE_IO.PUT(POFS);
					   --TEXT_IO.NEW_LINE;

					   search_english(input_word, pofs);

					   exit over_line;

				end parse_line_english_to_latin;

			 elsif language = latin_to_english  then

			parse_word_latin_to_english:
				declare
				   input_word : constant string := w(j..k);
				   entering_pa_last : integer := 0;
				   entering_trpa_last    : integer := 0;
				   have_done_enclitic : boolean := false;

				   procedure pass(input_word : string);

				   procedure enclitic is
					  save_do_fixes  : boolean := words_mode(do_fixes);
					  save_do_only_fixes  : boolean := words_mdev(do_only_fixes);
					  enclitic_limit : integer := 4;
					  try : constant string := lower_case(input_word);
				   begin
					  --TEXT_IO.PUT_LINE("Entering ENCLITIC  HAVE DONE = " & BOOLEAN'IMAGE(HAVE_DONE_ENCLITIC));
					  --if WORDS_MODE(TRIM_OUTPUT)  and (PA_LAST > 0)  then    return;   end if;
					  if have_done_enclitic  then    return;   end if;

					  entering_pa_last := pa_last;
					  if pa_last > 0 then enclitic_limit := 1; end if;
				  loop_over_enclitic_tackons:
					  for i in 1..enclitic_limit  loop   --  If have parse, only do que of que, ne, ve, (est)

					 remove_a_tackon:
						 declare
							less : constant string :=
							  subtract_tackon(try, tackons(i));
							--SUBTRACT_TACKON(INPUT_WORD, TACKONS(I));
							save_pa_last  : integer := 0;
						 begin
							--TEXT_IO.PUT_LINE("In ENCLITIC     LESS/TACKON  = " & LESS & "/" & TACKONS(I).TACK);
							if less  /= try  then       --  LESS is less
														--WORDS_MODE(DO_FIXES) := FALSE;
							   word_package.word(less, pa, pa_last);
							   --TEXT_IO.PUT_LINE("In ENCLITICS after WORD NO_FIXES  LESS = " & LESS & "   PA_LAST = " & INTEGER'IMAGE(PA_LAST));

							   if pa_last = 0  then

								  save_pa_last := pa_last;
								  try_slury(less, pa, pa_last, line_number, word_number);
								  if save_pa_last /= 0   then
									 if (pa_last - 1) - save_pa_last = save_pa_last  then
										pa_last := save_pa_last;
									 end if;
								  end if;

							   end if;

							   --  Do not SYNCOPE if there is a verb TO_BE or compound already there
							   --  I do this here and below, it might be combined but it workd now
							   for i in 1..pa_last  loop
								  --PARSE_RECORD_IO.PUT(PA(I)); TEXT_IO.NEW_LINE;
								  if pa(i).ir.qual.pofs = v and then
									pa(i).ir.qual.v.con = (5, 1)  then
									 no_syncope := true;
								  end if;
							   end loop;

							   --TEXT_IO.PUT_LINE("In ENCLITICS after SLURY  LESS = " & LESS & "   PA_LAST = " & INTEGER'IMAGE(PA_LAST));
							   sypa_last := 0;
							   if words_mdev(do_syncope)  and not no_syncope  then
								  syncope(less, sypa, sypa_last);  --  Want SYNCOPE second to make cleaner LIST
																   --TEXT_IO.PUT_LINE("In ENCLITIC after SYNCOPE  LESS = " & LESS & "   SYPA_LAST = " & INTEGER'IMAGE(SYPA_LAST));
								  pa_last := pa_last + sypa_last;   --  Make syncope another array to avoid PA_LAST = 0 problems
								  pa(1..pa_last) := pa(1..pa_last-sypa_last) & sypa(1..sypa_last);  --  Add SYPA to PA
								  sypa(1..syncope_max) := (1..syncope_max => null_parse_record);   --  Clean up so it does not repeat
								  sypa_last := 0;
							   end if;
							   no_syncope := false;
							   --  Restore FIXES
							   --WORDS_MODE(DO_FIXES) := SAVE_DO_FIXES;

							   words_mdev(do_only_fixes) := true;
							   word(input_word, pa, pa_last);
							   --TEXT_IO.PUT_LINE("In ENCLITICS after ONLY_FIXES  LESS = " & LESS & "   PA_LAST = " & INTEGER'IMAGE(PA_LAST));
							   words_mdev(do_only_fixes) := save_do_only_fixes;

							   if pa_last > entering_pa_last  then      --  have a possible word
								  pa_last := pa_last + 1;
								  pa(entering_pa_last+2..pa_last) :=
									pa(entering_pa_last+1..pa_last-1);
								  pa(entering_pa_last+1) := (tackons(i).tack,
															 ((tackon, null_tackon_record), 0, null_ending_record, x, x),
															 addons, dict_io.count(tackons(i).mnpc));

								  have_done_enclitic := true;
							   end if;
							   exit loop_over_enclitic_tackons;
							end if;
						 end remove_a_tackon;
					  end loop loop_over_enclitic_tackons;
				   end enclitic;

				   procedure tricks_enclitic is
					  try : constant string := lower_case(input_word);
				   begin
					  --TEXT_IO.PUT_LINE("Entering TRICKS_ENCLITIC    PA_LAST = " & INTEGER'IMAGE(PA_LAST));
					  --if WORDS_MODE(TRIM_OUTPUT)  and (PA_LAST > 0)  then    return;   end if;
					  if have_done_enclitic  then    return;   end if;

					  entering_trpa_last := trpa_last;
				  loop_over_enclitic_tackons:
					  for i in 1..4  loop   --  que, ne, ve, (est)

					 remove_a_tackon:
						 declare
							less : constant string :=
							  --SUBTRACT_TACKON(LOWER_CASE(INPUT_WORD), TACKONS(I));
							  subtract_tackon(try, tackons(i));
						 begin
							--TEXT_IO.PUT_LINE("In TRICKS_ENCLITIC     LESS/TACKON  = " & LESS & "/" & TACKONS(I).TACK);
							if less  /= try  then       --  LESS is less
														--PASS(LESS);
							   try_tricks(less, trpa, trpa_last, line_number, word_number);
							   --TEXT_IO.PUT_LINE("In TRICKS_ENCLITICS after TRY_TRICKS  LESS = " & LESS & "   TRPA_LAST = " & INTEGER'IMAGE(TRPA_LAST));
							   if trpa_last > entering_trpa_last  then      --  have a possible word
								  trpa_last := trpa_last + 1;
								  trpa(entering_trpa_last+2..trpa_last) :=
									trpa(entering_trpa_last+1..trpa_last-1);
								  trpa(entering_trpa_last+1) := (tackons(i).tack,
																 ((tackon, null_tackon_record), 0, null_ending_record, x, x),
																 addons, dict_io.count(tackons(i).mnpc));
							   end if;
							   exit loop_over_enclitic_tackons;
							end if;
						 end remove_a_tackon;
					  end loop loop_over_enclitic_tackons;
				   end tricks_enclitic;

				   procedure pass(input_word : string) is
					  --  This is the core logic of the program, everything else is details
					  save_pa_last  : integer := 0;
					  save_do_fixes  : boolean := words_mode(do_fixes);
					  save_do_only_fixes  : boolean := words_mdev(do_only_fixes);
					  save_do_tricks : boolean := words_mode(do_tricks);
				   begin
					  --TEXT_IO.PUT_LINE("Entering PASS with >" & INPUT_WORD);
					  --  Do straight WORDS without FIXES/TRICKS, is the word in the dictionary
					  words_mode(do_fixes) := false;
					  roman_numerals(input_word, pa, pa_last);
					  word(input_word, pa, pa_last);

					  --TEXT_IO.PUT_LINE("SLURY-   PA_LAST = " & INTEGER'IMAGE(PA_LAST));
					  --for JK in 1..PA_LAST  loop
					  -- f PARSE_RECORD_IO.PUT(PA(JK)); TEXT_IO.NEW_LINE;
					  --end loop;

					  if pa_last = 0  then
						 try_slury(input_word, pa, pa_last, line_number, word_number);
					  end if;

					  --  Do not SYNCOPE if there is a verb TO_BE or compound already there
					  for i in 1..pa_last  loop
						 --PARSE_RECORD_IO.PUT(PA(I)); TEXT_IO.NEW_LINE;
						 if pa(i).ir.qual.pofs = v and then
						   pa(i).ir.qual.v.con = (5, 1)  then
							no_syncope := true;
						 end if;
					  end loop;

					  -- --  WITH THE DICTIONARY BETTER, LET US FORGET THIS - a and c DONE, e and i STILL BUT NOT MANY
					  --  SAVE_PA_LAST := PA_LAST;
					  --  --  BIG PROBLEM HERE
					  --  --  If I do SLURY everytime, then each case where there is an aps- and abs- in dictionary
					  --  --  will show up twice, straight and SLURY, in the ourout - For either input
					  --  --  But if I only do SLURY if there is no hit, then some incomplete pairs will not
					  --  --  fully express (illuxit has two entries, inluxit has only one of them) (inritas)
					  --  --  So I will do SLURY and if it produces only 2 more PR (XXX and GEN), kill it, otherwise use it only
					  --  --  Still have a problem if there are other intervening results, not slurried.
					  --  --  Or if there is syncope
					  --  TRY_SLURY(INPUT_WORD, PA, PA_LAST, LINE_NUMBER, WORD_NUMBER);
					  ----TEXT_IO.PUT_LINE("SLURY+   PA_LAST = " & INTEGER'IMAGE(PA_LAST));
					  --  if SAVE_PA_LAST /= 0   then
					  --    if (PA_LAST - 2) = SAVE_PA_LAST  then
					  --      PA_LAST := SAVE_PA_LAST;
					  --      XXX_MEANING := NULL_MEANING_TYPE;
					  ----TEXT_IO.PUT_LINE("SLURY!   PA_LAST = " & INTEGER'IMAGE(PA_LAST));
					  --    end if;
					  --  end if;
					  ----TEXT_IO.PUT_LINE("1  PASS_BLOCK for  " & INPUT_WORD & "   PA_LAST = " & INTEGER'IMAGE(PA_LAST));

					  --  Pure SYNCOPE
					  sypa_last := 0;
					  if words_mdev(do_syncope)  and not no_syncope  then
						 syncope(input_word, sypa, sypa_last);
						 pa_last := pa_last + sypa_last;   --  Make syncope another array to avoid PA-LAST = 0 problems
						 pa(1..pa_last) := pa(1..pa_last-sypa_last) & sypa(1..sypa_last);  --  Add SYPA to PA
						 sypa(1..syncope_max) := (1..syncope_max => null_parse_record);   --  Clean up so it does not repeat
						 sypa_last := 0;
					  end if;
					  no_syncope := false;

					  --TEXT_IO.PUT_LINE("2  PASS_BLOCK for  " & INPUT_WORD & "   PA_LAST = " & INTEGER'IMAGE(PA_LAST));

					  --  There may be a vaild simple parse, if so it is most probable
					  --  But I have to allow for the possibility that -que is answer, not colloque V
					  enclitic;

					  --  Restore FIXES
					  words_mode(do_fixes) := save_do_fixes;
					  --TEXT_IO.PUT_LINE("3  PASS_BLOCK for  " & INPUT_WORD & "   PA_LAST = " & INTEGER'IMAGE(PA_LAST));

					  --  Now with only fixes
					  if pa_last = 0  and then
						words_mode(do_fixes)  then
						 words_mdev(do_only_fixes) := true;
						 --TEXT_IO.PUT_LINE("3a PASS_BLOCK for  " & INPUT_WORD & "   PA_LAST = " & INTEGER'IMAGE(PA_LAST));
						 word(input_word, pa, pa_last);
						 --TEXT_IO.PUT_LINE("3b PASS_BLOCK for  " & INPUT_WORD & "   PA_LAST = " & INTEGER'IMAGE(PA_LAST));
						 sypa_last := 0;
						 if words_mdev(do_syncope)  and not no_syncope  then
							syncope(input_word, sypa, sypa_last);
							--TEXT_IO.PUT_LINE("3c PASS_BLOCK for  " & INPUT_WORD & "   PA_LAST = " & INTEGER'IMAGE(PA_LAST));
							pa_last := pa_last + sypa_last;   --  Make syncope another array to avoid PA-LAST = 0 problems
							pa(1..pa_last) := pa(1..pa_last-sypa_last) & sypa(1..sypa_last);  --  Add SYPA to PA
							sypa(1..syncope_max) := (1..syncope_max => null_parse_record);   --  Clean up so it does not repeat
							sypa_last := 0;
						 end if;
						 no_syncope := false;

						 --TEXT_IO.PUT_LINE("4  PASS_BLOCK for  " & INPUT_WORD & "   PA_LAST = " & INTEGER'IMAGE(PA_LAST));
						 enclitic;

						 --TEXT_IO.PUT_LINE("5  PASS_BLOCK for  " & INPUT_WORD & "   PA_LAST = " & INTEGER'IMAGE(PA_LAST));
						 words_mdev(do_only_fixes) := save_do_only_fixes;
					  end if;
					  --TEXT_IO.PUT_LINE("6  PASS_BLOCK for  " & INPUT_WORD & "   PA_LAST = " & INTEGER'IMAGE(PA_LAST));
					  --  ROMAN_NUMERALS(INPUT_WORD, PA, PA_LAST);

					  --  If Pure WORDS and ENCLITICS found something OK, otherwise proceed
					  --    if PA_LAST = 0  or        --  If no go, try syncope, fixes
					  --      (not WORDS_MODE(TRIM_OUTPUT)) or
					  --       WORDS_MDEV(DO_FIXES_ANYWAY) then
					  --
					  --
					  --     --  If SYNCOPE does it, then OK, otherwise proceed
					  --     --  Do not try FIXES (aud+i+i) on audii since SYNCOPE worked
					  --     --  Now try FIXES
					  --     if PA_LAST = 0  or (not WORDS_MODE(TRIM_OUTPUT)) or
					  --       WORDS_MDEV(DO_FIXES_ANYWAY)  then
					  --      --TRY_SLURY(INPUT_WORD, PA, PA_LAST, LINE_NUMBER, WORD_NUMBER);
					  --       if PA_LAST = 0  then
					  --       WORD(INPUT_WORD, PA, PA_LAST);
					  --         SYPA_LAST := 0;
					  --         --  SYNCOPE after TRICK
					  --         SYNCOPE(INPUT_WORD, SYPA, SYPA_LAST);  --  Want SYNCOPE second to make cleaner LIST
					  --       end if;
					  --     end if;
					  --     PA_LAST := PA_LAST + SYPA_LAST;   --  Make syncope another array to avoid PA_LAST = 0 problems
					  --     PA(1..PA_LAST) := PA(1..PA_LAST-SYPA_LAST) & SYPA(1..SYPA_LAST);  --  Add SYPA to PA
					  --     SYPA(1..SYNCOPE_MAX) := (1..SYNCOPE_MAX => NULL_PARSE_RECORD);   --  Clean up so it does not repeat
					  --     SYPA_LAST := 0;
					  --
					  --
					  -- end if;   --  on A_LAST = 0

				   end pass;

				begin   --  PARSE
				   xxx_meaning := null_meaning_type;

			   pass_block:
				   begin
					  pa_last := 0;
					  word_number := word_number + 1;

					  pass(input_word);

				   end pass_block;

				   --TEXT_IO.PUT_LINE("After PASS_BLOCK for  " & INPUT_WORD & "   PA_LAST = " & INTEGER'IMAGE(PA_LAST));

				   --if (PA_LAST = 0) or DO_TRICKS_ANYWAY  then    --  WORD failed, try to modify the word
				   if (pa_last = 0)  and then
					 not (words_mode(ignore_unknown_names)  and capitalized)  then
					  --  WORD failed, try to modify the word
					  --TEXT_IO.PUT_LINE("WORDS fail me");
					  if words_mode(do_tricks)  then
						 --TEXT_IO.PUT_LINE("DO_TRICKS      PA_LAST    TRPA_LAST  " & INTEGER'IMAGE(PA_LAST) & "   " & INTEGER'IMAGE(TRPA_LAST));
						 words_mode(do_tricks) := false;  --  Turn it off so wont be circular
						 try_tricks(input_word, trpa, trpa_last, line_number, word_number);
						 --TEXT_IO.PUT_LINE("DONE_TRICKS    PA_LAST    TRPA_LAST  " & INTEGER'IMAGE(PA_LAST) & "   " & INTEGER'IMAGE(TRPA_LAST));
						 if trpa_last = 0  then
							tricks_enclitic;
						 end if;
						 words_mode(do_tricks) := true;   --  Turn it back on
					  end if;

					  pa_last := pa_last + trpa_last;   --  Make TRICKS another array to avoid PA-LAST = 0 problems
					  pa(1..pa_last) := pa(1..pa_last-trpa_last) & trpa(1..trpa_last);  --  Add SYPA to PA
					  trpa(1..tricks_max) := (1..tricks_max => null_parse_record);   --  Clean up so it does not repeat
					  trpa_last := 0;

				   end if;

				   --TEXT_IO.PUT_LINE("After TRICKS " & INTEGER'IMAGE(PA_LAST));

				   --======================================================================

				   --  At this point we have done what we can with individual words
				   --  Now see if there is something we can do with word combinations
				   --  For this we have to look ahead

				   if pa_last > 0   then    --  But PA may be killed by ALLOW in LIST_STEMS
					  if words_mode(do_compounds)  and
						not (configuration = only_meanings)  then
					 compounds_with_sum:
						 declare
							nw : string(1..2500) := (others => ' ');
							nk : integer := 0;

							compound_tense : inflections_package.tense_type := x;
							compound_tvm   : inflections_package.tense_voice_mood_record;
							ppl_on : boolean := false;

							sum_info : verb_record := ((5, 1),
													   (x, active, x),
													   0,
													   x);

							--  ESSE_INFO : VERB_RECORD := ((5, 1),
							--                              (PRES, ACTIVE, INF),
							--                               0,
							--                               X);

							ppl_info : vpar_record := ((0, 0),
													   x,
													   x,
													   x,
													   (x, x, x));

							supine_info : supine_record := ((0, 0),
															x,
															x,
															x);

							procedure look_ahead is
							   j : integer := 0;
							begin
							   for i in k+2..l  loop
								  --  Although I have removed punctuation above, it may not always be so
								  exit when (line(i) = ' ' or line(i) = ',' or line(i) = '-'
											   or line(i) = ';' or line(i) = ':' or line(i) = '.'
											   or line(i) = '(' or line(i) = '[' or line(i) = '{' or line(i) = '<'
											   or line(i) = ')' or line(i) = ']' or line(i) = '}' or line(i) = '>');
								  j := j + 1;
								  nw(j) := line(i);
								  nk := i;
							   end loop;
							end look_ahead;

							function next_word return string is
							begin
							   return trim(nw);
							end next_word;

							function is_sum(t : string) return boolean is
							   sa : constant array (mood_type range ind..sub,
													tense_type range pres..futp,
													number_type range s..p,
													person_type range 1..3)
								 of string(1..9) :=
								 (
								  (         --  IND
											(("sum      ", "es       ", "est      "), ("sumus    ", "estis    ", "sunt     ")),
											(("eram     ", "eras     ", "erat     "), ("eramus   ", "eratis   ", "erant    ")),
											(("ero      ", "eris     ", "erit     "), ("erimus   ", "eritis   ", "erunt    ")),
											(("fui      ", "fuisti   ", "fuit     "), ("fuimus   ", "fuistis  ", "fuerunt  ")),
											(("fueram   ", "fueras   ", "fuerat   "), ("fueramus ", "fueratis ", "fuerant  ")),
											(("fuero    ", "fueris   ", "fuerit   "), ("fuerimus ", "fueritis ", "fuerunt  "))
								  ),
								  (         --  SUB
											(("sim      ", "sis      ", "sit      "), ("simus    ", "sitis    ", "sint     ")),
											(("essem    ", "esses    ", "esset    "), ("essemus  ", "essetis  ", "essent   ")),
											(("zzz      ", "zzz      ", "zzz      "), ("zzz      ", "zzz      ", "zzz      ")),
											(("fuerim   ", "fueris   ", "fuerit   "), ("fuerimus ", "fueritis ", "fuerint  ")),
											(("fuissem  ", "fuisses  ", "fuisset  "), ("fuissemus", "fuissetis", "fuissent ")),
											(("zzz      ", "zzz      ", "zzz      "), ("zzz      ", "zzz      ", "zzz      "))
								  )
								 );

							begin
							   if t = ""  then
								  return false;
							   elsif t(t'first) /= 's'  and
								 t(t'first) /= 'e'  and
								 t(t'first) /= 'f'      then
								  return false;
							   end if;
							   for l in mood_type range ind..sub  loop
								  for k in tense_type range pres..futp  loop
									 for j in number_type range s..p  loop
										for i in person_type range 1..3  loop
										   if trim(t) = trim(sa(l, k, j, i))  then
											  sum_info := ((5, 1), (k, active, l), i, j);
											  return true;     --  Only one of the forms can agree
										   end if;
										end loop;
									 end loop;
								  end loop;
							   end loop;
							   return false;
							end is_sum;

							function is_esse(t : string) return boolean is
							begin
							   return trim(t) = "esse";
							end is_esse;

							function is_fuisse(t : string) return boolean is
							begin
							   return trim(t) = "fuisse";
							end is_fuisse;

							function is_iri(t : string) return boolean is
							begin
							   return trim(t) = "iri";
							end is_iri;

						 begin

							--  Look ahead for sum
							look_ahead;
							if is_sum(next_word)  then                 --  On NEXT_WORD = sum, esse, iri

							   for i in 1..pa_last  loop    --  Check for PPL
								  if pa(i).ir.qual.pofs = vpar and then
									pa(i).ir.qual.vpar.cs = nom  and then
									pa(i).ir.qual.vpar.number = sum_info.number  and then
									( (pa(i).ir.qual.vpar.tense_voice_mood = (perf, passive, ppl)) or
										(pa(i).ir.qual.vpar.tense_voice_mood = (fut,  active,  ppl)) or
										(pa(i).ir.qual.vpar.tense_voice_mood = (fut,  passive, ppl)) )  then

									 --  There is at least one hit, fix PA, and advance J over the sum
									 k := nk;

								  end if;
							   end loop;

							   if k = nk  then      --  There was a PPL hit
							  clear_pas_nom_ppl:
								  declare
									 j : integer := pa_last;
								  begin
									 while j >= 1  loop        --  Sweep backwards to kill empty suffixes
										if ((pa(j).ir.qual.pofs = prefix) and then (ppl_on))  then
										   null;
										elsif ((pa(j).ir.qual.pofs = suffix) and then (ppl_on))  then
										   null;
										elsif ((pa(j).ir.qual.pofs = tackon) and then (ppl_on))  then
										   null;

										elsif pa(j).ir.qual.pofs = vpar and then
										  pa(j).ir.qual.vpar.cs = nom  and then
										  pa(j).ir.qual.vpar.number = sum_info.number  then

										   if pa(j).ir.qual.vpar.tense_voice_mood = (perf, passive, ppl)  then
											  ppl_on := true;

											  case sum_info.tense_voice_mood.tense is  --  Allows PERF for sum
												 when pres | perf  =>  compound_tense := perf;
												 when impf | plup  =>  compound_tense := plup;
												 when fut          =>  compound_tense := futp;
												 when others       =>  compound_tense := x;
											  end case;
											  compound_tvm := (compound_tense, passive, sum_info.tense_voice_mood.mood);

											  ppl_info := (pa(j).ir.qual.vpar.con,   --  In this case, there is 1
														   pa(j).ir.qual.vpar.cs,    --  although several different
														   pa(j).ir.qual.vpar.number,--  dictionary entries may fit
														   pa(j).ir.qual.vpar.gender,--  all have same PPL_INFO
														   pa(j).ir.qual.vpar.tense_voice_mood);
											  ppp_meaning :=
												head("PERF PASSIVE PPL + verb TO_BE => PASSIVE perfect system",
													 max_meaning_size);

										   elsif pa(j).ir.qual.vpar.tense_voice_mood = (fut, active,  ppl)  then
											  ppl_on := true;
											  compound_tense := sum_info.tense_voice_mood.tense;
											  compound_tvm := (compound_tense, active, sum_info.tense_voice_mood.mood);

											  ppl_info := (pa(j).ir.qual.vpar.con,   --  In this case, there is 1
														   pa(j).ir.qual.vpar.cs,    --  although several different
														   pa(j).ir.qual.vpar.number,--  dictionary entries may fit
														   pa(j).ir.qual.vpar.gender,--  all have same PPL_INFO
														   pa(j).ir.qual.vpar.tense_voice_mood);
											  ppp_meaning := head(
																  "FUT ACTIVE PPL + verb TO_BE => ACTIVE Periphrastic - about to, going to",
																  max_meaning_size);

										   elsif pa(j).ir.qual.vpar.tense_voice_mood = (fut, passive, ppl)  then
											  ppl_on := true;
											  compound_tense := sum_info.tense_voice_mood.tense;
											  compound_tvm := (compound_tense, passive, sum_info.tense_voice_mood.mood);

											  ppl_info := (pa(j).ir.qual.vpar.con,   --  In this case, there is 1
														   pa(j).ir.qual.vpar.cs,    --  although several different
														   pa(j).ir.qual.vpar.number,--  dictionary entries may fit
														   pa(j).ir.qual.vpar.gender,--  all have same PPL_INFO
														   pa(j).ir.qual.vpar.tense_voice_mood);
											  ppp_meaning := head(
																  "FUT PASSIVE PPL + verb TO_BE => PASSIVE Periphrastic - should/ought/had to",
																  max_meaning_size);

										   end if;
										else
										   pa(j..pa_last-1) := pa(j+1..pa_last);
										   pa_last := pa_last - 1;
										   ppl_on := false;
										end if;
										j := j - 1;
									 end loop;
								  end clear_pas_nom_ppl;

								  pa_last := pa_last + 1;
								  pa(pa_last) :=
									(head("PPL+" & next_word, max_stem_size),
									 ((v,
									   (ppl_info.con,
										compound_tvm,
										sum_info.person,
										sum_info.number)
									  ), 0, null_ending_record, x, a),
									 ppp, null_mnpc);

							   end if;

							elsif is_esse(next_word) or is_fuisse(next_word)  then     --  On NEXT_WORD

							   for i in 1..pa_last  loop    --  Check for PPL
								  if pa(i).ir.qual.pofs = vpar and then
									(((pa(i).ir.qual.vpar.tense_voice_mood = (perf, passive, ppl)) and
										is_esse(next_word)) or
									   ((pa(i).ir.qual.vpar.tense_voice_mood = (fut,  active,  ppl)) or
										  (pa(i).ir.qual.vpar.tense_voice_mood = (fut,  passive, ppl))) )  then

									 --  There is at least one hit, fix PA, and advance J over the sum
									 k := nk;

								  end if;
							   end loop;

							   if k = nk  then      --  There was a PPL hit
							  clear_pas_ppl:
								  declare
									 j : integer := pa_last;
								  begin
									 while j >= 1  loop        --  Sweep backwards to kill empty suffixes
										if ((pa(j).ir.qual.pofs = prefix) and then (ppl_on))  then
										   null;
										elsif ((pa(j).ir.qual.pofs = suffix) and then (ppl_on))  then
										   null;
										elsif ((pa(j).ir.qual.pofs = tackon) and then (ppl_on))  then
										   null;

										elsif pa(j).ir.qual.pofs = vpar   then

										   if pa(j).ir.qual.vpar.tense_voice_mood = (perf, passive, ppl)  then
											  ppl_on := true;

											  compound_tvm := (perf, passive, inf);

											  ppl_info := (pa(j).ir.qual.vpar.con,   --  In this case, there is 1
														   pa(j).ir.qual.vpar.cs,    --  although several different
														   pa(j).ir.qual.vpar.number,--  dictionary entries may fit
														   pa(j).ir.qual.vpar.gender,--  all have same PPL_INFO
														   pa(j).ir.qual.vpar.tense_voice_mood);
											  ppp_meaning :=
												head("PERF PASSIVE PPL + esse => PERF PASSIVE INF",
													 max_meaning_size);

										   elsif pa(j).ir.qual.vpar.tense_voice_mood = (fut, active,  ppl)  then
											  ppl_on := true;
											  ppl_info := (pa(j).ir.qual.vpar.con,   --  In this case, there is 1
														   pa(j).ir.qual.vpar.cs,    --  although several different
														   pa(j).ir.qual.vpar.number,--  dictionary entries may fit
														   pa(j).ir.qual.vpar.gender,--  all have same PPL_INFO
														   pa(j).ir.qual.vpar.tense_voice_mood);
											  if is_esse(next_word)  then
												 compound_tvm := (fut, active, inf);
												 ppp_meaning := head(
																	 "FUT ACTIVE PPL + esse => PRES Periphastic/FUT ACTIVE INF - be about/going to",
																	 max_meaning_size);
												 -- also peri COMPOUND_TVM := (PRES, ACTIVE, INF);
											  else   --  fuisse
												 compound_tvm := (perf, active, inf);
												 ppp_meaning := head(
																	 "FUT ACT PPL+fuisse => PERF ACT INF Periphrastic - to have been about/going to",
																	 max_meaning_size);
											  end if;

										   elsif pa(j).ir.qual.vpar.tense_voice_mood = (fut, passive, ppl)  then
											  ppl_on := true;

											  ppl_info := (pa(j).ir.qual.vpar.con,   --  In this case, there is 1
														   pa(j).ir.qual.vpar.cs,    --  although several different
														   pa(j).ir.qual.vpar.number,--  dictionary entries may fit
														   pa(j).ir.qual.vpar.gender,--  all have same PPL_INFO
														   pa(j).ir.qual.vpar.tense_voice_mood);
											  if is_esse(next_word)  then
												 compound_tvm := (pres, passive, inf);
												 ppp_meaning := head(
																	 "FUT PASSIVE PPL + esse => PRES PASSIVE INF",
																	 max_meaning_size);
												 -- also peri COMPOUND_TVM := (PRES, ACTIVE, INF);
											  else   --  fuisse
												 compound_tvm := (perf, passive, inf);
												 ppp_meaning := head(
																	 "FUT PASSIVE PPL + fuisse => PERF PASSIVE INF Periphrastic - about to, going to",
																	 max_meaning_size);
											  end if;

										   end if;
										else
										   pa(j..pa_last-1) := pa(j+1..pa_last);
										   pa_last := pa_last - 1;
										   ppl_on := false;
										end if;
										j := j - 1;
									 end loop;
								  end clear_pas_ppl;

								  pa_last := pa_last + 1;
								  pa(pa_last) :=
									(head("PPL+" & next_word, max_stem_size),
									 ((v,
									   (ppl_info.con,
										compound_tvm,
										0,
										x)
									  ), 0, null_ending_record, x, a),
									 ppp, null_mnpc);

							   end if;

							elsif is_iri(next_word)  then              --  On NEXT_WORD = sum, esse, iri
																	   --  Look ahead for sum

							   for j in 1..pa_last  loop    --  Check for SUPINE
								  if pa(j).ir.qual.pofs = supine   and then
									pa(j).ir.qual.supine.cs = acc    then
									 --  There is at least one hit, fix PA, and advance J over the iri
									 k := nk;

								  end if;
							   end loop;

							   if k = nk  then      --  There was a SUPINE hit
							  clear_pas_supine:
								  declare
									 j : integer := pa_last;
								  begin
									 while j >= 1  loop        --  Sweep backwards to kill empty suffixes
										if ((pa(j).ir.qual.pofs = prefix) and then (ppl_on))  then
										   null;
										elsif ((pa(j).ir.qual.pofs = suffix) and then (ppl_on))  then
										   null;
										elsif ((pa(j).ir.qual.pofs = tackon) and then (ppl_on))  then
										   null;

										elsif pa(j).ir.qual.pofs = supine  and then
										  pa(j).ir.qual.supine.cs = acc  then

										   ppl_on := true;
										   supine_info := (pa(j).ir.qual.supine.con,
														   pa(j).ir.qual.supine.cs,
														   pa(j).ir.qual.supine.number,
														   pa(j).ir.qual.supine.gender);

										   pa_last := pa_last + 1;
										   pa(pa_last) :=
											 (head("SUPINE + iri", max_stem_size),
											  ((v,
												(supine_info.con,
												 (fut, passive, inf),
												 0,
												 x)
											   ), 0, null_ending_record, x, a),
											  ppp, null_mnpc);
										   ppp_meaning := head(
															   "SUPINE + iri => FUT PASSIVE INF - to be about/going/ready to be ~",
															   max_meaning_size);

										   k := nk;

										else
										   pa(j..pa_last-1) := pa(j+1..pa_last);
										   pa_last := pa_last - 1;
										   ppl_on := false;
										end if;
										j := j -1;
									 end loop;
								  end clear_pas_supine;
							   end if;

							end if;       --  On NEXT_WORD = sum, esse, iri

						 end compounds_with_sum;
					  end if;       --  On WORDS_MODE(DO_COMPOUNDS)

					  --========================================================================
				   end if;

				   --TEXT_IO.PUT_LINE("Before LISTing STEMS (PA_LAST > 0 to start) PA_LAST = " &
				   --INTEGER'IMAGE(PA_LAST));

				   if  words_mode(write_output_to_file)      then
					  list_stems(output, input_word, input_line, pa, pa_last);
				   else
					  list_stems(current_output, input_word, input_line, pa, pa_last);
				   end if;

				   --TEXT_IO.PUT_LINE("After LISTing STEMS (PA_LAST > 0 to start) PA_LAST = " &
				   --INTEGER'IMAGE(PA_LAST));

				   pa_last := 0;

				exception
				   when others  =>
					  put_stat("Exception    at "
								 & head(integer'image(line_number), 8) & head(integer'image(word_number), 4)
								 & "   " & head(input_word, 28) & "   "  & input_line);
					  raise;

				end parse_word_latin_to_english;

			 end if;

			 ----------------------------------------------------------------------
			 ----------------------------------------------------------------------

			 j := k + 1;    --  In case it is end of line and we don't look for ' '

			 exit when words_mdev(do_only_initial_word);

		  end loop over_line;        --  Loop on line

   exception
	  --   Have STORAGE_ERROR check in WORD too  ?????????????
	  when storage_error  =>    --  I want to again, at least twice
		 if words_mdev(do_pearse_codes) then
			text_io.put("00 ");
		 end if;
		 text_io.put_line(    --  ERROR_FILE,
							  "STORAGE_ERROR Exception in WORDS, try again");
		 storage_error_count := storage_error_count + 1;
		 if storage_error_count >= 4  then  raise; end if;
		 pa_last := 0;
	  when give_up =>
		 pa_last := 0;
		 raise;
	  when others  =>    --  I want to try to get on with the next line
		 text_io.put_line(    --  ERROR_FILE,
							  "Exception in PARSE_LINE processing " & input_line);
		 if words_mode(write_unknowns_to_file)  then
			if words_mdev(do_pearse_codes) then
			   text_io.put(unknowns, "00 ");
			end if;
			text_io.put(unknowns, input_line(j..k));
			text_io.set_col(unknowns, 30);
			inflections_package.integer_io.put(unknowns, line_number, 5);
			inflections_package.integer_io.put(unknowns, word_number, 3);
			text_io.put_line(unknowns, "    ========   ERROR      ");
		 end if;
		 pa_last := 0;
   end parse_line;

   --procedure CHANGE_LANGUAGE(C : CHARACTER) is
   --begin
   --  if UPPER_CASE(C) = 'L'  then
   --    LANGUAGE := LATIN_TO_ENGLISH;
   --    PREFACE.PUT_LINE("Language changed to " & LANGUAGE_TYPE'IMAGE(LANGUAGE));
   --  elsif UPPER_CASE(C) = 'E'  then
   --    if ENGLISH_DICTIONARY_AVAILABLE(GENERAL)  then
   --      LANGUAGE:= ENGLISH_TO_LATIN;
   --      PREFACE.PUT_LINE("Language changed to " & LANGUAGE_TYPE'IMAGE(LANGUAGE));
   --      PREFACE.PUT_LINE("Input a single English word (+ part of speech - N, ADJ, V, PREP, ...)");
   --    else
   --      PREFACE.PUT_LINE("No English dictionary available");
   --    end if;
   --  else
   --    PREFACE.PUT_LINE("Bad LANGAUGE input - no change, remains " & LANGUAGE_TYPE'IMAGE(LANGUAGE));
   --  end if;
   --exception
   --  when others  =>
   --    PREFACE.PUT_LINE("Bad LANGAUGE input - no change, remains " & LANGUAGE_TYPE'IMAGE(LANGUAGE));
   --end CHANGE_LANGUAGE;
   --
   --

begin              --  PARSE
				   --  All Rights Reserved   -   William Armstrong Whitaker

   --  INITIALIZE_WORD_PARAMETERS;
   --  INITIALIZE_DEVELOPER_PARAMETERS;
   --  INITIALIZE_WORD_PACKAGE;
   --
   if method = command_line_input  then
	  if trim(command_line) /= ""  then
		 parse_line(command_line);
	  end if;

   else

	  preface.put_line(
					   "Copyright (c) 1993-2006 - Free for any use - Version 1.97FC");
	  preface.put_line(
					   "For updates and latest version check http://www.erols.com/whitaker/words.htm");
	  preface.put_line(
					   "Comments? William Whitaker, Box 51225  Midland  TX  79710  USA - whitaker@erols.com");
	  preface.new_line;
	  preface.put_line(
					   "Input a word or line of Latin and ENTER to get the forms and meanings");
	  preface.put_line("    Or input " & start_file_character &
						 " and the name of a file containing words or lines");
	  preface.put_line("    Or input " & change_parameters_character &
						 " to change parameters and mode of the program");
	  preface.put_line("    Or input " & help_character &
						 " to get help wherever available on individual parameters");
	  preface.put_line(
					   "Two empty lines (just a RETURN/ENTER) from the keyboard exits the program");

	  if english_dictionary_available(general)  then
		 preface.put_line("English-to-Latin available");
		 preface.put_line(
						  change_language_character & "E changes to English-to-Latin, " &
							change_language_character & "L changes back     [tilde E]");
	  end if;

	  if configuration = only_meanings  then
		 preface.put_line(
						  "THIS VERSION IS HARDCODED TO GIVE DICTIONARY FORM AND MEANINGS ONLY");
		 preface.put_line(
						  "IT CANNOT BE MODIFIED BY CHANGING THE DO_MEANINGS_ONLY PARAMETER");
	  end if;

  get_input_lines:
	  loop
	 get_input_line:
		 begin                    --  Block to manipulate file of lines
			if (name(current_input) = name(standard_input))  then
			   scroll_line_number := integer(text_io.line(text_io.standard_output));
			   preface.new_line;
			   preface.put("=>");
			end if;

			line := blank_line;
			get_line(line, l);
			if (l = 0) or else (trim(line(1..l)) = "")  then
			   --LINE_NUMBER := LINE_NUMBER + 1;  --  Count blank lines
			   if (name(current_input) = name(standard_input))  then   --  INPUT is keyboard
				  preface.put("Blank exits =>");
				  get_line(line, l);             -- Second try
				  if (l = 0) or else (trim(line(1..l)) = "")  then  -- Two in a row
					 exit;
				  end if;
			   else                 --  INPUT is file
									--LINE_NUMBER := LINE_NUMBER + 1;   --  Count blank lines in file
				  if end_of_file(current_input) then
					 set_input(standard_input);
					 close(input);
				  end if;
			   end if;
			end if;

			if (trim(line(1..l)) /= "")  then  -- Not a blank line so L(1) (in file input)
			   if line(1) = start_file_character  then    --  To begin file of words
				  if (name(current_input) /= name(standard_input)) then
					 text_io.put_line("Cannot have file of words (@FILE) in an @FILE");
				  else
					 text_io.open(input, text_io.in_file, trim(line(2..l)));
					 text_io.set_input(input);
				  end if;
			   elsif line(1) = change_parameters_character  and then
				 (name(current_input) = name(standard_input)) and then
				 not config.suppress_preface  then
				  change_parameters;
			   elsif line(1) = change_language_character  then
				  -- (NAME(CURRENT_INPUT) = NAME(STANDARD_INPUT)) and then
				  --   not CONFIG.SUPPRESS_PREFACE  then
				  --TEXT_IO.PUT_LINE("CHANGE CHARACTER   " & TRIM(LINE));
				  change_language(line(2));
			   elsif --  CONFIGURATION = DEVELOPER_VERSION  and then    --  Allow anyone to do it
				 line(1) = change_developer_modes_character  and then
				 (name(current_input) = name(standard_input)) and then
				 not config.suppress_preface  then
				  change_developer_modes;
			   else
				  if (name(current_input) /= name(standard_input))  then
					 preface.new_line;
					 preface.put_line(line(1..l));
				  end if;
				  if words_mode(write_output_to_file)     then
					 if not config.suppress_preface     then
						new_line(output);
						text_io.put_line(output, line(1..l));
					 end if;
				  end if;
				  line_number := line_number + 1;  --  Count lines to be parsed
				  parse_line(line(1..l));
			   end if;
			end if;

		 exception
			when name_error | use_error =>
			   if (name(current_input) /= name(standard_input))  then
				  set_input(standard_input);
				  close(input);
			   end if;
			   put_line("An unknown or unacceptable file name. Try Again");
			when end_error =>          --  The end of the input file resets to CON:
			   if (name(current_input) /= name(standard_input))  then
				  set_input(standard_input);
				  close(input);
				  if method = command_line_files  then raise give_up; end if;
			   else
				  put_line("Raised END_ERROR, although in STANDARD_INPUT");
				  put_line("^Z is inappropriate keyboard input, WORDS should be terminated with a blank line");
				  raise give_up;
			   end if;
			when status_error =>      --  The end of the input file resets to CON:
			   put_line("Raised STATUS_ERROR");
		 end get_input_line;                     --  end Block to manipulate file of lines

	  end loop get_input_lines;          --  Loop on lines

   end if;     --  On command line input

   begin
	  stem_io.open(stem_file(local), stem_io.in_file,
				   add_file_name_extension(stem_file_name,
										   "LOCAL"));
	  --  Failure to OPEN will raise an exception, to be handled below
	  if stem_io.is_open(stem_file(local)) then
		 stem_io.delete(stem_file(local));
	  end if;
   exception
	  when others =>
		 null;      --  If cannot OPEN then it does not exist, so is deleted
   end;
   --  The rest of this seems like overkill, it might have been done elsewhere
   begin
	  if
		dict_io.is_open(dict_file(local)) then
		 dict_io.delete(dict_file(local));
	  else
		 dict_io.open(dict_file(local), dict_io.in_file,
					  add_file_name_extension(dict_file_name,
											  "LOCAL"));
		 dict_io.delete(dict_file(local));
	  end if;
   exception when others => null; end;   --  not there, so don't have to DELETE
   begin
	  if
		dict_io.is_open(dict_file(addons))  then
		 dict_io.delete(dict_file(addons));
	  else
		 dict_io.open(dict_file(addons), dict_io.in_file,
					  add_file_name_extension(dict_file_name,
											  "ADDONS"));
		 dict_io.delete(dict_file(addons));
	  end if;
   exception when others => null; end;   --  not there, so don't have to DELETE
   begin
	  if
		dict_io.is_open(dict_file(unique)) then
		 dict_io.delete(dict_file(unique));
	  else
		 dict_io.open(dict_file(unique), dict_io.in_file,
					  add_file_name_extension(dict_file_name,
											  "UNIQUE"));
		 dict_io.delete(dict_file(unique));
	  end if;
   exception when others => null; end;   --  not there, so don't have to DELETE

exception
   when storage_error  =>    --  Have tried at least twice, fail
	  preface.put_line("Continuing STORAGE_ERROR Exception in PARSE");
	  preface.put_line("If insufficient memory in DOS, try removing TSRs");
   when give_up  =>
	  preface.put_line("Giving up!");
   when others  =>
	  preface.put_line("Unexpected exception raised in PARSE");
end parse;