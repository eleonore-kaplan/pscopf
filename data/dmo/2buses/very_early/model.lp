minimize
obj: 5 c_lim_wind_1,2015_01_01T11_00_00,S1_ + 5 c_lim_wind_1,2015_01_01T11_00_00,S2_ + 0.0001 is_limited_wind_1,2015_01_01T11_00_00,S1_ + 0.0001 is_limited_wind_1,2015_01_01T11_00_00,S2_ + 25 c_imp_pos_moonwalk,2015_01_01T11_00_00,S1_ + 15 c_imp_pos_alta,2015_01_01T11_00_00,S2_ + 25 c_imp_pos_sundance,2015_01_01T11_00_00,S1_ + 25 c_imp_pos_moonwalk,2015_01_01T11_00_00,S2_ + 25 c_imp_pos_sundance,2015_01_01T11_00_00,S2_ + 15 c_imp_pos_alta,2015_01_01T11_00_00,S1_ + 25 c_imp_neg_moonwalk,2015_01_01T11_00_00,S1_ + 15 c_imp_neg_alta,2015_01_01T11_00_00,S2_ + 25 c_imp_neg_sundance,2015_01_01T11_00_00,S1_ + 25 c_imp_neg_moonwalk,2015_01_01T11_00_00,S2_ + 25 c_imp_neg_sundance,2015_01_01T11_00_00,S2_ + 15 c_imp_neg_alta,2015_01_01T11_00_00,S1_ + 0.0005 p_res_pos_2015_01_01T11_00_00,S2_ + 0.0005 p_res_pos_2015_01_01T11_00_00,S1_ + 0.0005 p_res_neg_2015_01_01T11_00_00,S2_ + 0.0005 p_res_neg_2015_01_01T11_00_00,S1_
subject to
c1_2: -1 p_lim_wind_1,2015_01_01T11_00_00,S1_ + 1 is_limited_x_p_lim_wind_1,2015_01_01T11_00_00,S1_ <= 0
c2_2: 1 is_limited_x_p_lim_wind_1,2015_01_01T11_00_00,S1_ - 53 is_limited_wind_1,2015_01_01T11_00_00,S1_ <= 0
c3_2: -1 p_lim_wind_1,2015_01_01T11_00_00,S1_ + 1 p_enr_wind_1,2015_01_01T11_00_00,S1_ <= 0
c4_2: -1 p_lim_wind_1,2015_01_01T11_00_00,S2_ + 1 is_limited_x_p_lim_wind_1,2015_01_01T11_00_00,S2_ <= 0
c5_2: 1 is_limited_x_p_lim_wind_1,2015_01_01T11_00_00,S2_ - 53 is_limited_wind_1,2015_01_01T11_00_00,S2_ <= 0
c6_2: -1 p_lim_wind_1,2015_01_01T11_00_00,S2_ + 1 p_enr_wind_1,2015_01_01T11_00_00,S2_ <= 0
c7_2: -200 p_is_imp_and_on_alta,2015_01_01T11_00_00,S1_ + 1 p_imp_alta,2015_01_01T11_00_00,S1_ <= 0
c8_2: -1 p_is_imp_alta,2015_01_01T11_00_00,S1_ + 1 p_is_imp_and_on_alta,2015_01_01T11_00_00,S1_ <= 0
c9_2: -1 p_on_alta,2015_01_01T11_00_00,S1_ + 1 p_is_imp_and_on_alta,2015_01_01T11_00_00,S1_ <= 0
c10_2: -200 p_is_imp_and_on_alta,2015_01_01T11_00_00,S2_ + 1 p_imp_alta,2015_01_01T11_00_00,S2_ <= 0
c11_2: -1 p_is_imp_alta,2015_01_01T11_00_00,S2_ + 1 p_is_imp_and_on_alta,2015_01_01T11_00_00,S2_ <= 0
c12_2: -1 p_on_alta,2015_01_01T11_00_00,S2_ + 1 p_is_imp_and_on_alta,2015_01_01T11_00_00,S2_ <= 0
c13_2: 1 p_start_alta,2015_01_01T11_00_00,S2_ - 1 p_on_alta,2015_01_01T11_00_00,S2_ <= 0
c14_2: 1 p_start_alta,2015_01_01T11_00_00,S2_ + 1 p_on_alta,2015_01_01T11_00_00,S2_ <= 1
c15_2: -200 p_is_imp_and_on_sundance,2015_01_01T11_00_00,S1_ + 1 p_imp_sundance,2015_01_01T11_00_00,S1_ <= 0
c16_2: -1 p_is_imp_sundance,2015_01_01T11_00_00,S1_ + 1 p_is_imp_and_on_sundance,2015_01_01T11_00_00,S1_ <= 0
c17_2: -1 p_on_sundance,2015_01_01T11_00_00,S1_ + 1 p_is_imp_and_on_sundance,2015_01_01T11_00_00,S1_ <= 0
c18_2: -200 p_is_imp_and_on_sundance,2015_01_01T11_00_00,S2_ + 1 p_imp_sundance,2015_01_01T11_00_00,S2_ <= 0
c19_2: -1 p_is_imp_sundance,2015_01_01T11_00_00,S2_ + 1 p_is_imp_and_on_sundance,2015_01_01T11_00_00,S2_ <= 0
c20: -1 p_on_sundance,2015_01_01T11_00_00,S2_ + 1 p_is_imp_and_on_sundance,2015_01_01T11_00_00,S2_ <= 0
c21: 1 p_start_sundance,2015_01_01T11_00_00,S2_ - 1 p_on_sundance,2015_01_01T11_00_00,S2_ <= 0
c22: 1 p_start_sundance,2015_01_01T11_00_00,S2_ + 1 p_on_sundance,2015_01_01T11_00_00,S2_ <= 1
c23: -200 p_is_imp_and_on_moonwalk,2015_01_01T11_00_00,S1_ + 1 p_imp_moonwalk,2015_01_01T11_00_00,S1_ <= 0
c24: -1 p_is_imp_moonwalk,2015_01_01T11_00_00,S1_ + 1 p_is_imp_and_on_moonwalk,2015_01_01T11_00_00,S1_ <= 0
c25: -1 p_on_moonwalk,2015_01_01T11_00_00,S1_ + 1 p_is_imp_and_on_moonwalk,2015_01_01T11_00_00,S1_ <= 0
c26: -200 p_is_imp_and_on_moonwalk,2015_01_01T11_00_00,S2_ + 1 p_imp_moonwalk,2015_01_01T11_00_00,S2_ <= 0
c27: -1 p_is_imp_moonwalk,2015_01_01T11_00_00,S2_ + 1 p_is_imp_and_on_moonwalk,2015_01_01T11_00_00,S2_ <= 0
c28: -1 p_on_moonwalk,2015_01_01T11_00_00,S2_ + 1 p_is_imp_and_on_moonwalk,2015_01_01T11_00_00,S2_ <= 0
c29: 1 p_start_moonwalk,2015_01_01T11_00_00,S2_ - 1 p_on_moonwalk,2015_01_01T11_00_00,S2_ <= 0
c30: 1 p_start_moonwalk,2015_01_01T11_00_00,S2_ + 1 p_on_moonwalk,2015_01_01T11_00_00,S2_ <= 1
c1_1: -1 p_lim_wind_1,2015_01_01T11_00_00,S1_ + 1 is_limited_x_p_lim_wind_1,2015_01_01T11_00_00,S1_ - 53 is_limited_wind_1,2015_01_01T11_00_00,S1_ >= -53
c2_1: 1 p_lim_wind_1,2015_01_01T11_00_00,S1_ + 1 c_lim_wind_1,2015_01_01T11_00_00,S1_ >= 51
c3_1: -1 p_lim_wind_1,2015_01_01T11_00_00,S2_ + 1 is_limited_x_p_lim_wind_1,2015_01_01T11_00_00,S2_ - 53 is_limited_wind_1,2015_01_01T11_00_00,S2_ >= -53
c4_1: 1 p_lim_wind_1,2015_01_01T11_00_00,S2_ + 1 c_lim_wind_1,2015_01_01T11_00_00,S2_ >= 53
c5_1: 1 p_imp_alta,2015_01_01T11_00_00,S1_ >= 0
c6_1: -1 p_is_imp_alta,2015_01_01T11_00_00,S1_ - 1 p_on_alta,2015_01_01T11_00_00,S1_ + 1 p_is_imp_and_on_alta,2015_01_01T11_00_00,S1_ >= -1
c7_1: 1 p_imp_alta,2015_01_01T11_00_00,S2_ >= 0
c8_1: -1 p_is_imp_alta,2015_01_01T11_00_00,S2_ - 1 p_on_alta,2015_01_01T11_00_00,S2_ + 1 p_is_imp_and_on_alta,2015_01_01T11_00_00,S2_ >= -1
c9_1: 1 p_start_alta,2015_01_01T11_00_00,S2_ >= 0
c10_1: 1 p_imp_sundance,2015_01_01T11_00_00,S1_ >= 0
c11_1: -1 p_is_imp_sundance,2015_01_01T11_00_00,S1_ - 1 p_on_sundance,2015_01_01T11_00_00,S1_ + 1 p_is_imp_and_on_sundance,2015_01_01T11_00_00,S1_ >= -1
c12_1: 1 p_imp_sundance,2015_01_01T11_00_00,S2_ >= 0
c13_1: -1 p_is_imp_sundance,2015_01_01T11_00_00,S2_ - 1 p_on_sundance,2015_01_01T11_00_00,S2_ + 1 p_is_imp_and_on_sundance,2015_01_01T11_00_00,S2_ >= -1
c14_1: 1 p_start_sundance,2015_01_01T11_00_00,S2_ >= 0
c15_1: 1 p_imp_moonwalk,2015_01_01T11_00_00,S1_ >= 0
c16_1: -1 p_is_imp_moonwalk,2015_01_01T11_00_00,S1_ - 1 p_on_moonwalk,2015_01_01T11_00_00,S1_ + 1 p_is_imp_and_on_moonwalk,2015_01_01T11_00_00,S1_ >= -1
c17_1: 1 p_imp_moonwalk,2015_01_01T11_00_00,S2_ >= 0
c18_1: -1 p_is_imp_moonwalk,2015_01_01T11_00_00,S2_ - 1 p_on_moonwalk,2015_01_01T11_00_00,S2_ + 1 p_is_imp_and_on_moonwalk,2015_01_01T11_00_00,S2_ >= -1
c19_1: 1 p_start_moonwalk,2015_01_01T11_00_00,S2_ >= 0
c1: -1 is_limited_x_p_lim_wind_1,2015_01_01T11_00_00,S1_ + 1 p_enr_wind_1,2015_01_01T11_00_00,S1_ + 51 is_limited_wind_1,2015_01_01T11_00_00,S1_ = 51
c2: -1 is_limited_x_p_lim_wind_1,2015_01_01T11_00_00,S2_ + 1 p_enr_wind_1,2015_01_01T11_00_00,S2_ + 53 is_limited_wind_1,2015_01_01T11_00_00,S2_ = 53
c3: 1 p_imposable_alta,2015_01_01T11_00_00,S1_ - 1 c_imp_pos_alta,2015_01_01T11_00_00,S1_ + 1 c_imp_neg_alta,2015_01_01T11_00_00,S1_ = 29
c4: 1 p_imposable_alta,2015_01_01T11_00_00,S1_ + 29 p_is_imp_alta,2015_01_01T11_00_00,S1_ - 1 p_imp_alta,2015_01_01T11_00_00,S1_ = 29
c5: 1 p_imposable_alta,2015_01_01T11_00_00,S2_ - 1 c_imp_pos_alta,2015_01_01T11_00_00,S2_ + 1 c_imp_neg_alta,2015_01_01T11_00_00,S2_ = 30
c6: 1 p_imposable_alta,2015_01_01T11_00_00,S2_ + 30 p_is_imp_alta,2015_01_01T11_00_00,S2_ - 1 p_imp_alta,2015_01_01T11_00_00,S2_ = 30
c7: 1 p_imposable_sundance,2015_01_01T11_00_00,S1_ - 1 c_imp_pos_sundance,2015_01_01T11_00_00,S1_ + 1 c_imp_neg_sundance,2015_01_01T11_00_00,S1_ = 0
c8: 1 p_imposable_sundance,2015_01_01T11_00_00,S1_ - 1 p_imp_sundance,2015_01_01T11_00_00,S1_ = 0
c9: 1 p_imposable_sundance,2015_01_01T11_00_00,S2_ - 1 c_imp_pos_sundance,2015_01_01T11_00_00,S2_ + 1 c_imp_neg_sundance,2015_01_01T11_00_00,S2_ = 0
c10: 1 p_imposable_sundance,2015_01_01T11_00_00,S2_ - 1 p_imp_sundance,2015_01_01T11_00_00,S2_ = 0
c11: 1 p_start_sundance,2015_01_01T11_00_00,S1_ - 1 p_on_sundance,2015_01_01T11_00_00,S1_ = 0
c12: 1 p_imposable_moonwalk,2015_01_01T11_00_00,S1_ - 1 c_imp_pos_moonwalk,2015_01_01T11_00_00,S1_ + 1 c_imp_neg_moonwalk,2015_01_01T11_00_00,S1_ = 25
c13: 1 p_imposable_moonwalk,2015_01_01T11_00_00,S1_ + 25 p_is_imp_moonwalk,2015_01_01T11_00_00,S1_ - 1 p_imp_moonwalk,2015_01_01T11_00_00,S1_ = 25
c14: 1 p_imposable_moonwalk,2015_01_01T11_00_00,S2_ - 1 c_imp_pos_moonwalk,2015_01_01T11_00_00,S2_ + 1 c_imp_neg_moonwalk,2015_01_01T11_00_00,S2_ = 25
c15: 1 p_imposable_moonwalk,2015_01_01T11_00_00,S2_ + 25 p_is_imp_moonwalk,2015_01_01T11_00_00,S2_ - 1 p_imp_moonwalk,2015_01_01T11_00_00,S2_ = 25
c16: 1 p_enr_wind_1,2015_01_01T11_00_00,S1_ + 1 p_imposable_alta,2015_01_01T11_00_00,S1_ + 1 p_imposable_sundance,2015_01_01T11_00_00,S1_ + 1 p_imposable_moonwalk,2015_01_01T11_00_00,S1_ + 1 p_res_pos_2015_01_01T11_00_00,S1_ - 1 p_res_neg_2015_01_01T11_00_00,S1_ = 105
c17: 1 p_enr_wind_1,2015_01_01T11_00_00,S2_ + 1 p_imposable_alta,2015_01_01T11_00_00,S2_ + 1 p_imposable_sundance,2015_01_01T11_00_00,S2_ + 1 p_imposable_moonwalk,2015_01_01T11_00_00,S2_ + 1 p_res_pos_2015_01_01T11_00_00,S2_ - 1 p_res_neg_2015_01_01T11_00_00,S2_ = 105
c18: -0.5 p_enr_wind_1,2015_01_01T11_00_00,S1_ - 0.5 p_imposable_alta,2015_01_01T11_00_00,S1_ + 0.5 p_imposable_sundance,2015_01_01T11_00_00,S1_ + 0.5 p_imposable_moonwalk,2015_01_01T11_00_00,S1_ + 1 p_flow_1_2,_2015_01_01T11_00_00,S1_ = 52.5
c19: -0.5 p_enr_wind_1,2015_01_01T11_00_00,S2_ - 0.5 p_imposable_alta,2015_01_01T11_00_00,S2_ + 0.5 p_imposable_sundance,2015_01_01T11_00_00,S2_ + 0.5 p_imposable_moonwalk,2015_01_01T11_00_00,S2_ + 1 p_flow_1_2,_2015_01_01T11_00_00,S2_ = 52.5
Bounds
p_enr_wind_1,2015_01_01T11_00_00,S1_ <= 51
p_enr_wind_1,2015_01_01T11_00_00,S2_ <= 53
p_res_pos_2015_01_01T11_00_00,S1_ <= 0
p_res_neg_2015_01_01T11_00_00,S1_ <= 0
p_res_pos_2015_01_01T11_00_00,S2_ <= 0
p_res_neg_2015_01_01T11_00_00,S2_ <= 0
p_flow_1_2,_2015_01_01T11_00_00,S1_ <= 100
p_flow_1_2,_2015_01_01T11_00_00,S2_ <= 100
p_lim_wind_1,2015_01_01T11_00_00,S1_ >= 0
is_limited_x_p_lim_wind_1,2015_01_01T11_00_00,S1_ >= 0
c_lim_wind_1,2015_01_01T11_00_00,S1_ >= 0
p_enr_wind_1,2015_01_01T11_00_00,S1_ >= 0
p_lim_wind_1,2015_01_01T11_00_00,S2_ >= 0
is_limited_x_p_lim_wind_1,2015_01_01T11_00_00,S2_ >= 0
c_lim_wind_1,2015_01_01T11_00_00,S2_ >= 0
p_enr_wind_1,2015_01_01T11_00_00,S2_ >= 0
p_imposable_alta,2015_01_01T11_00_00,S1_ >= 0
c_imp_pos_alta,2015_01_01T11_00_00,S1_ >= 0
c_imp_neg_alta,2015_01_01T11_00_00,S1_ >= 0
p_imposable_alta,2015_01_01T11_00_00,S2_ >= 0
c_imp_pos_alta,2015_01_01T11_00_00,S2_ >= 0
c_imp_neg_alta,2015_01_01T11_00_00,S2_ >= 0
p_imposable_sundance,2015_01_01T11_00_00,S1_ >= 0
c_imp_pos_sundance,2015_01_01T11_00_00,S1_ >= 0
c_imp_neg_sundance,2015_01_01T11_00_00,S1_ >= 0
p_imposable_sundance,2015_01_01T11_00_00,S2_ >= 0
c_imp_pos_sundance,2015_01_01T11_00_00,S2_ >= 0
c_imp_neg_sundance,2015_01_01T11_00_00,S2_ >= 0
p_imposable_moonwalk,2015_01_01T11_00_00,S1_ >= 0
c_imp_pos_moonwalk,2015_01_01T11_00_00,S1_ >= 0
c_imp_neg_moonwalk,2015_01_01T11_00_00,S1_ >= 0
p_imposable_moonwalk,2015_01_01T11_00_00,S2_ >= 0
c_imp_pos_moonwalk,2015_01_01T11_00_00,S2_ >= 0
c_imp_neg_moonwalk,2015_01_01T11_00_00,S2_ >= 0
p_res_pos_2015_01_01T11_00_00,S1_ >= 0
p_res_neg_2015_01_01T11_00_00,S1_ >= 0
p_res_pos_2015_01_01T11_00_00,S2_ >= 0
p_res_neg_2015_01_01T11_00_00,S2_ >= 0
p_flow_1_2,_2015_01_01T11_00_00,S1_ >= -100
p_flow_1_2,_2015_01_01T11_00_00,S2_ >= -100
p_imp_alta,2015_01_01T11_00_00,S1_ free
p_imp_alta,2015_01_01T11_00_00,S2_ free
p_imp_sundance,2015_01_01T11_00_00,S1_ free
p_imp_sundance,2015_01_01T11_00_00,S2_ free
p_imp_moonwalk,2015_01_01T11_00_00,S1_ free
p_imp_moonwalk,2015_01_01T11_00_00,S2_ free
Binary
is_limited_wind_1,2015_01_01T11_00_00,S1_
is_limited_wind_1,2015_01_01T11_00_00,S2_
p_is_imp_alta,2015_01_01T11_00_00,S1_
p_start_alta,2015_01_01T11_00_00,S1_
p_on_alta,2015_01_01T11_00_00,S1_
p_is_imp_and_on_alta,2015_01_01T11_00_00,S1_
p_is_imp_alta,2015_01_01T11_00_00,S2_
p_start_alta,2015_01_01T11_00_00,S2_
p_on_alta,2015_01_01T11_00_00,S2_
p_is_imp_and_on_alta,2015_01_01T11_00_00,S2_
p_is_imp_sundance,2015_01_01T11_00_00,S1_
p_start_sundance,2015_01_01T11_00_00,S1_
p_on_sundance,2015_01_01T11_00_00,S1_
p_is_imp_and_on_sundance,2015_01_01T11_00_00,S1_
p_is_imp_sundance,2015_01_01T11_00_00,S2_
p_start_sundance,2015_01_01T11_00_00,S2_
p_on_sundance,2015_01_01T11_00_00,S2_
p_is_imp_and_on_sundance,2015_01_01T11_00_00,S2_
p_is_imp_moonwalk,2015_01_01T11_00_00,S1_
p_start_moonwalk,2015_01_01T11_00_00,S1_
p_on_moonwalk,2015_01_01T11_00_00,S1_
p_is_imp_and_on_moonwalk,2015_01_01T11_00_00,S1_
p_is_imp_moonwalk,2015_01_01T11_00_00,S2_
p_start_moonwalk,2015_01_01T11_00_00,S2_
p_on_moonwalk,2015_01_01T11_00_00,S2_
p_is_imp_and_on_moonwalk,2015_01_01T11_00_00,S2_
End
