<?xml version = "1.0" encoding="UTF-8" standalone="yes"?>
<CPLEXSolution version="1.2">
 <header
   problemName="model.lp"
   solutionName="incumbent"
   solutionIndex="-1"
   objectiveValue="25.0001"
   solutionTypeValue="3"
   solutionTypeString="primal"
   solutionStatusValue="101"
   solutionStatusString="integer optimal solution"
   solutionMethodString="mip"
   primalFeasible="1"
   dualFeasible="1"
   MIPNodes="0"
   MIPIterations="8"
   writeLevel="1"/>
 <quality
   epInt="1.0000000000000001e-05"
   epRHS="9.9999999999999995e-07"
   maxIntInfeas="4.4408920985006262e-16"
   maxPrimalInfeas="0"
   maxX="80"
   maxSlack="200"/>
 <linearConstraints>
  <constraint name="c1_2" index="0" slack="51"/>
  <constraint name="c2_2" index="1" slack="0"/>
  <constraint name="c3_2" index="2" slack="0"/>
  <constraint name="c4_2" index="3" slack="0"/>
  <constraint name="c5_2" index="4" slack="2"/>
  <constraint name="c6_2" index="5" slack="0"/>
  <constraint name="c7_2" index="6" slack="0"/>
  <constraint name="c8_2" index="7" slack="0"/>
  <constraint name="c9_2" index="8" slack="0"/>
  <constraint name="c10_2" index="9" slack="170.99999999999994"/>
  <constraint name="c11_2" index="10" slack="0"/>
  <constraint name="c12_2" index="11" slack="0"/>
  <constraint name="c13_2" index="12" slack="0.99999999999999956"/>
  <constraint name="c14_2" index="13" slack="4.4408920985006262e-16"/>
  <constraint name="c15_2" index="14" slack="200"/>
  <constraint name="c16_2" index="15" slack="0"/>
  <constraint name="c17_2" index="16" slack="0"/>
  <constraint name="c18_2" index="17" slack="200"/>
  <constraint name="c19_2" index="18" slack="0"/>
  <constraint name="c20" index="19" slack="0"/>
  <constraint name="c21" index="20" slack="1"/>
  <constraint name="c22" index="21" slack="0"/>
  <constraint name="c23" index="22" slack="0"/>
  <constraint name="c24" index="23" slack="0"/>
  <constraint name="c25" index="24" slack="0"/>
  <constraint name="c26" index="25" slack="0"/>
  <constraint name="c27" index="26" slack="0"/>
  <constraint name="c28" index="27" slack="0"/>
  <constraint name="c29" index="28" slack="0"/>
  <constraint name="c30" index="29" slack="1"/>
  <constraint name="c1_1" index="30" slack="-2"/>
  <constraint name="c2_1" index="31" slack="0"/>
  <constraint name="c3_1" index="32" slack="0"/>
  <constraint name="c4_1" index="33" slack="0"/>
  <constraint name="c5_1" index="34" slack="0"/>
  <constraint name="c6_1" index="35" slack="-1"/>
  <constraint name="c7_1" index="36" slack="-28.999999999999986"/>
  <constraint name="c8_1" index="37" slack="-4.4408920985006262e-16"/>
  <constraint name="c9_1" index="38" slack="0"/>
  <constraint name="c10_1" index="39" slack="0"/>
  <constraint name="c11_1" index="40" slack="0"/>
  <constraint name="c12_1" index="41" slack="0"/>
  <constraint name="c13_1" index="42" slack="0"/>
  <constraint name="c14_1" index="43" slack="0"/>
  <constraint name="c15_1" index="44" slack="0"/>
  <constraint name="c16_1" index="45" slack="-1"/>
  <constraint name="c17_1" index="46" slack="0"/>
  <constraint name="c18_1" index="47" slack="-1"/>
  <constraint name="c19_1" index="48" slack="0"/>
  <constraint name="c1" index="49" slack="0"/>
  <constraint name="c2" index="50" slack="0"/>
  <constraint name="c3" index="51" slack="0"/>
  <constraint name="c4" index="52" slack="0"/>
  <constraint name="c5" index="53" slack="0"/>
  <constraint name="c6" index="54" slack="0"/>
  <constraint name="c7" index="55" slack="0"/>
  <constraint name="c8" index="56" slack="0"/>
  <constraint name="c9" index="57" slack="0"/>
  <constraint name="c10" index="58" slack="0"/>
  <constraint name="c11" index="59" slack="0"/>
  <constraint name="c12" index="60" slack="0"/>
  <constraint name="c13" index="61" slack="0"/>
  <constraint name="c14" index="62" slack="0"/>
  <constraint name="c15" index="63" slack="0"/>
  <constraint name="c16" index="64" slack="0"/>
  <constraint name="c17" index="65" slack="0"/>
  <constraint name="c18" index="66" slack="0"/>
  <constraint name="c19" index="67" slack="0"/>
 </linearConstraints>
 <variables>
  <variable name="c_lim_wind_1,2015_01_01T11_00_00,S1_" index="0" value="0"/>
  <variable name="c_lim_wind_1,2015_01_01T11_00_00,S2_" index="1" value="2"/>
  <variable name="is_limited_wind_1,2015_01_01T11_00_00,S1_" index="2" value="-0"/>
  <variable name="is_limited_wind_1,2015_01_01T11_00_00,S2_" index="3" value="1"/>
  <variable name="c_imp_pos_moonwalk,2015_01_01T11_00_00,S1_" index="4" value="0"/>
  <variable name="c_imp_pos_alta,2015_01_01T11_00_00,S2_" index="5" value="0"/>
  <variable name="c_imp_pos_sundance,2015_01_01T11_00_00,S1_" index="6" value="0"/>
  <variable name="c_imp_pos_moonwalk,2015_01_01T11_00_00,S2_" index="7" value="0"/>
  <variable name="c_imp_pos_sundance,2015_01_01T11_00_00,S2_" index="8" value="0"/>
  <variable name="c_imp_pos_alta,2015_01_01T11_00_00,S1_" index="9" value="0"/>
  <variable name="c_imp_neg_moonwalk,2015_01_01T11_00_00,S1_" index="10" value="0"/>
  <variable name="c_imp_neg_alta,2015_01_01T11_00_00,S2_" index="11" value="1"/>
  <variable name="c_imp_neg_sundance,2015_01_01T11_00_00,S1_" index="12" value="0"/>
  <variable name="c_imp_neg_moonwalk,2015_01_01T11_00_00,S2_" index="13" value="0"/>
  <variable name="c_imp_neg_sundance,2015_01_01T11_00_00,S2_" index="14" value="0"/>
  <variable name="c_imp_neg_alta,2015_01_01T11_00_00,S1_" index="15" value="0"/>
  <variable name="p_res_pos_2015_01_01T11_00_00,S2_" index="16" value="0"/>
  <variable name="p_res_pos_2015_01_01T11_00_00,S1_" index="17" value="0"/>
  <variable name="p_res_neg_2015_01_01T11_00_00,S2_" index="18" value="0"/>
  <variable name="p_res_neg_2015_01_01T11_00_00,S1_" index="19" value="0"/>
  <variable name="p_lim_wind_1,2015_01_01T11_00_00_" index="20" value="51"/>
  <variable name="is_limited_x_p_lim_wind_1,2015_01_01T11_00_00,S1_" index="21" value="0"/>
  <variable name="p_enr_wind_1,2015_01_01T11_00_00,S1_" index="22" value="51"/>
  <variable name="is_limited_x_p_lim_wind_1,2015_01_01T11_00_00,S2_" index="23" value="51"/>
  <variable name="p_enr_wind_1,2015_01_01T11_00_00,S2_" index="24" value="51"/>
  <variable name="p_is_imp_and_on_alta,2015_01_01T11_00_00,S1_" index="25" value="0"/>
  <variable name="p_imp_alta,2015_01_01T11_00_00,S1_" index="26" value="0"/>
  <variable name="p_is_imp_alta,2015_01_01T11_00_00,S1_" index="27" value="-0"/>
  <variable name="p_on_alta,2015_01_01T11_00_00,S1_" index="28" value="0"/>
  <variable name="p_is_imp_and_on_alta,2015_01_01T11_00_00,S2_" index="29" value="0.99999999999999956"/>
  <variable name="p_imp_alta,2015_01_01T11_00_00,S2_" index="30" value="28.999999999999986"/>
  <variable name="p_is_imp_alta,2015_01_01T11_00_00,S2_" index="31" value="0.99999999999999956"/>
  <variable name="p_on_alta,2015_01_01T11_00_00,S2_" index="32" value="0.99999999999999956"/>
  <variable name="p_start_alta,2015_01_01T11_00_00,S2_" index="33" value="0"/>
  <variable name="p_is_imp_and_on_sundance,2015_01_01T11_00_00,S1_" index="34" value="1"/>
  <variable name="p_imp_sundance,2015_01_01T11_00_00,S1_" index="35" value="0"/>
  <variable name="p_is_imp_sundance,2015_01_01T11_00_00,S1_" index="36" value="1"/>
  <variable name="p_on_sundance,2015_01_01T11_00_00,S1_" index="37" value="1"/>
  <variable name="p_is_imp_and_on_sundance,2015_01_01T11_00_00,S2_" index="38" value="1"/>
  <variable name="p_imp_sundance,2015_01_01T11_00_00,S2_" index="39" value="0"/>
  <variable name="p_is_imp_sundance,2015_01_01T11_00_00,S2_" index="40" value="1"/>
  <variable name="p_on_sundance,2015_01_01T11_00_00,S2_" index="41" value="1"/>
  <variable name="p_start_sundance,2015_01_01T11_00_00,S2_" index="42" value="0"/>
  <variable name="p_is_imp_and_on_moonwalk,2015_01_01T11_00_00,S1_" index="43" value="0"/>
  <variable name="p_imp_moonwalk,2015_01_01T11_00_00,S1_" index="44" value="0"/>
  <variable name="p_is_imp_moonwalk,2015_01_01T11_00_00,S1_" index="45" value="-0"/>
  <variable name="p_on_moonwalk,2015_01_01T11_00_00,S1_" index="46" value="0"/>
  <variable name="p_is_imp_and_on_moonwalk,2015_01_01T11_00_00,S2_" index="47" value="0"/>
  <variable name="p_imp_moonwalk,2015_01_01T11_00_00,S2_" index="48" value="0"/>
  <variable name="p_is_imp_moonwalk,2015_01_01T11_00_00,S2_" index="49" value="-0"/>
  <variable name="p_on_moonwalk,2015_01_01T11_00_00,S2_" index="50" value="0"/>
  <variable name="p_start_moonwalk,2015_01_01T11_00_00,S2_" index="51" value="0"/>
  <variable name="p_imposable_alta,2015_01_01T11_00_00,S1_" index="52" value="29"/>
  <variable name="p_imposable_alta,2015_01_01T11_00_00,S2_" index="53" value="29"/>
  <variable name="p_imposable_sundance,2015_01_01T11_00_00,S1_" index="54" value="0"/>
  <variable name="p_imposable_sundance,2015_01_01T11_00_00,S2_" index="55" value="0"/>
  <variable name="p_start_sundance,2015_01_01T11_00_00,S1_" index="56" value="1"/>
  <variable name="p_imposable_moonwalk,2015_01_01T11_00_00,S1_" index="57" value="25"/>
  <variable name="p_imposable_moonwalk,2015_01_01T11_00_00,S2_" index="58" value="25"/>
  <variable name="p_flow_1_2,_2015_01_01T11_00_00,S1_" index="59" value="80"/>
  <variable name="p_flow_1_2,_2015_01_01T11_00_00,S2_" index="60" value="80"/>
 </variables>
</CPLEXSolution>
