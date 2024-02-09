library busbuddy_app.globel;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:requests/requests.dart';

// import 'package:google_maps_flutter/google_maps_flutter.dart';
void printWarning(String text) {
  print('\x1B[33m$text\x1B[0m');
}

void printError(String text) {
  print('\x1B[31m$text\x1B[0m');
}

const int distanceFilter = 50;

String userId = "";
String userName = "";
String userEmail = "";
String userPhone = "";
String userType = ""; // user type to indicate the type of user he is
String userImageStr = "";
String userDefaultRouteId = "";
String userDefaultRouteName = "";
String userDefaultStationId = "";
String userDefaultStationName = "";
String teacherDepartment = "";
String teacherDesignation = "";
String teacherResidence = "";
String staffRole = "";
String serverAddr = 'http://3.141.62.8:6969';
String serverIp = '$serverAddr/api/';
String runningTripId = "";
String trackingTripId = "";
String fcmId = "";
bool wmg = false;
StreamSubscription<Position>? positionStream;

MemoryImage userAvatar = MemoryImage(base64Decode(
    "iVBORw0KGgoAAAANSUhEUgAAAQAAAAEACAYAAABccqhmAAAABHNCSVQICAgIfAhkiAAAAAlwSFlzAABHUAAAR1ABqCmTtQAAABl0RVh0U29mdHdhcmUAd3d3Lmlua3NjYXBlLm9yZ5vuPBoAACAASURBVHic7d15fBT1/T/w13t2cxEgJySE+z7lEvEEAlKtCl6wUUQhgNDWPmx//dZvPWhlglq1tfbb2vb31aqEwwMCeB9o1XAooBDDFQTkEuQKEK4lyWZn3t8/DBggCdns7nx2Z97PvzTZzLyA7GtnPjPz+RBEVLvnnj8n+lDRjmOM1mBqDUY7Zm4JQhKA5gCSQEgCIwlAygUbYDQDwQ2gAkA5gOMAKgGcAuCt/tohIhxixj4iHALhgGFo++OqYva9+urDZVb9WUXokeoA4uJuuP/vcU1PHutGbPY0iXqCuBcxegBoDyBJaTjGYRC+BbCNCVvB+JZY25ZI5qb8fL1CaTZxUVIAESY3V4/3mtoAaDwY4MEABgHoDMClOFqgqgCUEKOINRQxUJTgT1w3d+5/e1UHEz+SAlDMM+mPLYCqEcQ8lIHLAfQFEKM6V5gYANYxYykBhTFVccvlFEItKQCLjZ6mN0mooiGmySOJMBI/vOE11bkUMQGsB7CUgI+aAJ/KaYO1pAAsMO7eJzL8VVW3gHA7gGwAcYojRSovgI/B9K47xv3uay9OP6g6kN1JAYTJnbl6B5PoNma+DcDVcO6nfGOZAL4EaLHh5tcWv6jvVR3IjqQAQmj8eL15pRu3EnAPCNdC/n5DxQSwEqACdyy/8toL+mHVgexCfkGDpOu6VvIdRsBELgO3A0hQncnmKsB4l5le7tOJl+i6bqoOFM2kABrJM+mPLYh9Uxn4GYB2qvM41A6A/tdvxrz8xpxHjqgOE42kAALkydX7M3A/AXcBiFedRwAAKoiwwID2r0WzHl2tOkw0kQJoAF3XtY27cCsBvwYwVHUeUa/lBDy1IF//AACrDhPppADqoeu6VrKLbmLiPDAGqM4jArKBGc8c7ohXC3XdrzpMpJICqEW2rrtb7KJxAD8CoIfqPCIIjG8Beqq0I8+WIriQFMC5aOzEvLsIrIPQRXUYEVJbiGn6gtkzFkNODc6SAqjmmTDzSmjmMwCuUp1FhNVXzPTwwtkzPlEdJBI4vgA8k/ReMPE0CKNUZxGW+khz4bfzX9I3qg6ikmML4K67nkypiql8AsDU6gkxhNMw/Aw8F+eH/sor+gnVcVRwZAGMzc3zEPg5ABmqs4iIcIAZDy6crc+Fw8YHHFUAnsmPdYdp/AvACNVZRERarrlwn5NOCxxRAB6PHoummA7Gg5BHcUX9fEx47HB7POWEy4a2L4AxE2f21sicA2Cg6iwiqqzXCJPmz9KLVAcJJ9sWgK7r2qZddD/AT0M+9UXjVDHwLHnxaEGB7lMdJhxsWQCeKXoXGJgNuaYvQuNLU8O4RS/rO1QHCTXbzVLjyc27BwaKIW9+ETqDNRNFORP1HNVBQs02RwC5uXr8KcLTxPiV6izC1ubGG4m/sMv05rYogOpD/gIA/VVnEQ7A2KiZrpz5c/+wWXWUYEX9KUDOxLwxMLAW8uYXViH0MV3GqpzcvNGqowQrmo8AKCc373cMfhLR/ecQ0YsZ+FOfDngkWucmjMo3Tm6uHn8aeJGB8aqzCEFAQZyROCkaxwWirgDunKxnGQbeAmGQ6ixC1FDsIvfNr8/6/R7VQQIRVQXgmTjzUpD5FoDWqrMIUYvvNRd+Gk3PEkTNIODYXD0bZH4KefOLyNXaNLDcM2nmMNVBGioqCsAzUb+ZgA8ANFedRYiLSAabSzyT8u5QHaQhIn7Nec/EvCkgzAMQqzqLEA3kBnB7r/7Zh0uKC79SHaY+EV0AYyfqvyPC3xElRypC1EAE3NSr3/BTJesKV6oOU5eILYDqN//TiLKBSiFqIsJ1vQZkGyXFhctUZ6lNRBZAziT9AQB/Up1DiFAgYESf/sPNTRFYAhH36erJ1R8C8KTqHLbB8GoaHXPHuE/GxsacJgBut1YV43adc+dald/Q/H4zhgH4qqqa+H3+ZqbJySAkqgluPwR6dEH+jMdU56gpogrAk5v33wDLJ39gqmJiXLvSU5MOZmam+1tnprqz2qQ3zWqZ1iIpOTHd5XIFNRmK3zAqjx3zHj546Ejp93sPn/r+wFH//oOHY44cOdGyyufvKDMqB4p+V5A/48+qU5wRMQUwNjfvfgL/XXWOSEdEh9LTk7b36dXJ169Pp5bt2mV0dLs0JasU+w2zYvfugzvWb9xRuqlke2zpkRNdmLmFiixRhAm4d0G+/rLqIECEFEDORD2HCa9BRvtrw3GxMZv79u1ycMSQfm1at27RVXWgevB3ew9+u3TZuu/XbdyR6fNVybqKtTNgkqdgzow3VAdRXgBjc/VsAj6EzNt3Dk3Tvu/Xt/PWUTdc2bVFWlIb1Xkao/TQsT3vLlm5ff2GHd0N02ylOk+EqSCTblwwZ8ZnKkMoLYAxE/S+moZlAJJU5ogkiU3ii2+/ZYhv0MDulxJRRF6lCZRpsvHl2s1r33x7Rfzp8sq+qvNEkBOmqWUvmvPo16oCKCuA26c83t5l+L8AkKUqQyRp2jSh6O47R7p69ejQT3WWcNpUsnPdvPn/Ya+3QiZwAQDGXsOIGbx43vT9KnavpAA89+lNcRqfA3D8p4Hbpe26dfSQ/UOv6Xul6ixWKl6/vWjOq0uS/H6js+osEWBtRSyGvvOCftrqHas4xKTevbNfBTBcwb4jB8Pf75JOS3/3m3G9O3bI7KA6jtUyM1JbXTt8YOLefUdWlJaWtYWzB4CzYgx03lRcuNjqHVteAJ6J+qMg3Gf1fiOJS3Ptvv++2/aNHH7p5Zpmj/P8xtA0zT1oQLcOnTpmlRR9vbWSmZ08FtSnV//hXFJcuNTKnVp6CpCTq9/KwCI4uO2Tmid+9chv7+qSkBifojpLJDl9urzsyWde23H8hPdS1VkUYpg0xsrLg5YVQPUafSsBNLNqn5Gmc8espb+67/Zr7DK6H2qmycZf/7no89279w9VnUWhYxq7Bs2f/YftVuzMkl/E0dP0JjEmfwQgKq9nh8IlvTp+dt/Pbs0mIsce/VwMEWlXDu7Zfu/3pUsPlR7roDqPIvFMfM3g/tlziosLw746sSW/jAmV+BuA3lbsKxL16N7uP1Mnj3L2oGcDERGmTR41rEe39paeC0eYgV7Gs1bsKOxHANVTI/0x3PuJVG1apS3/9S/HZhOR8rsuo8mggd3aF6//duUpb3lb1VmUIFzWZ8DwrZuKC8M6wWhYfynvmPhYZ5OMIjh0Lr+4uNgNT86c2sXt0hJUZ4lGfr+/8pFHX9xR4avqqTqLIidNDf3DuSpx2E4Bpk17PsYk4zU49M1PoLKHH7grTd78jed2u+Me+u1dSUR0XHUWRZppJvJ1XQ/b+zRsGy6r3P8wgMvCtf1Id8voq0pSU5rJbc5BSk1rnjXqhis2qc6h0JCS3fivcG08LAUwZoLeF4Tp4dh2NEhObrp6xLCBV6vOYRc/GTHoqqTmiWtV51CFGY+NmTgzLIPoIS+AadOej9E0zIJzp/Gu/MXUWzNUh7Cb+6bdkgbApzqHIvEamXOmTXs+JtQbDnkBHPMdeAjAwFBvN1q0a5e5ulVGSgfVOeymVWZah7ZtWn6pOodCA6vfWyEV0gIYM0Hvy+Dfh3KbUcYYn3OtLF0WJuNzrm0DICqX4Q4FBj/imaJ3CeU2Q1kApGl4Ds499EeL9OTVrTJT5fHWMMnKSu+QntY8olfaCbN4GPhXKDcYsgIYO1G/B4CT7+FGztjhjn3OwSpjbxvm9GnKfzI2V78zVBsLSQGMH683J8JTodhWtHK5tO+6d2nTR3UOu+vZvX0fl6Z9rzqHSgT89dZcPTkU2wpJAfhiMBOAoyd97N613Q5EwCSrdkdE6NqlzbeqcyiW6SbkhWJDQRdA9fVJR0/wAQDXj7yspeoMTjFyxCDHrz1AJu67457Hgr5FOugC0Mj8K4CQX5+MMkc6tM9w6v3qluvaOaung28P/gHBbbqNJ4LdTFAFMDZXzwbwk2BDRLvU5KbfytN+1iEiat6sidNPAwDGbWNzZw4JZhPBFAARnD3wd0a3ru0sn83V6Tp3zDqlOkMkIJjPIIixp0YXwNjcvLEALm/sz9tJz+7t5fKfxXr2au/0y4FnDM6ZqHsa+8ONKgCPZ4GLiEMyCmkHWa3T01VncJo2rVqmqc4QKZjwuMezoFGT+zSqAChx82QwZNALABj+FinN5bFfi2W0TMqCg28LPk9XTixp1FFAwAXg8SxwMfjBxuzMjkijw5pbc+ztz6q43e44TaOjqnNECmJMb8zEIQH/ADXdnANA7nev5naRDEYpopHmVZ0hYhD6lOyk2wL9sUALgJjl078ml9tdoTqDU2kurVx1hkjCxL9HgFcEAiqAnFz9BgC2Xr02YHL1XxkNYNUZIkz/nNy8UYH8QEAFwIyHA8vjAKZUgCqm1O8FGPzrQF7f4AIYM2nm5SBcE3gke/P7/XI9WhHDNJqozhCBRtwxRW/wU6kNLgAXTMc/8FMbk1mm/VbENOTvvhZkGPhVQ1/coAIYN01PZ0ZO4zMJIaxCwN23Tfhjg26UalABGD6aAiA+qFRCCKskxGhV9zbkhRctAF3XNQZPCz6TEMIqDP45GjBIetEC2LSTbgDQKRShhBCW6ZAzIS/7Yi+6+CkA8eRQpBFCWIs1nnCx19RbAJ5pTyUBuCFkiYQQVvLcPPnpeh9Vr7cAuKrCA0AutQgRnRLjzPIx9b2g3gIgxvjQ5hFCWGxifd+sswDunPR4Wzh8oQ8hbGCYZ8LjdS5XV2cB+E3/uPq+L4SICkRk3FrXN+t8gxOh3nMHIUR0YOI65wmotQDG3ftEBoBBYUskhLBS9rhpeq3zVtZaAFVG1ei6vieEiDouvw+1zhNQ65ucgNHhzSOEsBSh1tOACwrA43k2AYyR4U8khLAMY+QN9/897vwvX1AA3PTEtQBkogUh7KVJs+NlV53/xdpOARy/1p8QdsQuvvb8r11QAMQYZk0cIYSlajm1P6cAPFP0VACXWBZICGGlQXfd9WRKzS+cUwBkYOj5XxNC2Iaryu3LrvmFc97sJsu9/0LYmsbnnOKfewSgIdvSMEIIaxEG1/zfswVwzz1/TgSjr/WJhBCWYQzwePSzi9meLYByt7cfgEatMS6EIrI0WODizWY/ftCfLQDNlId/GoGvGzFoi+oQTnXTT6/YBimBgJH542nA2QJgwgA1caLXZYN6FN740ytk4FSR664ddPWggd2Wqc4RhS4sAAADFQSJWk2axBfffcfIbNU5nO6ecdcNTUiI26g6RzShGo/6awCQm6vHA+ipLFH0MX4x9eYEIpLVaRUjIvr5vTfHAzBUZ4kiXbN13Q1UF4CXtd4AYpRGiiIt0pNXt2+b0V11DvGDju0zu6SnJa1RnSOKxKbtQhegugBI425q80SXa4cNkE/+CJM9pJ8MBgbABfQAzowB8A9tIBrEO/iynv1UhxDnumJw734AylXniBYmUU+gugBMliOAhoqPj93pdrtkvoQIExvrToiNi92tOke0IOYfC4BIjgAaKjEx4aTqDKJ2zRLjT6jOEDUYPxYAgK4Ko0SV2Fi3X3UGUbvY2Fj5t2koQnsA0KqfD05THCdqyLPSkYvkHycQ6bm5erxWFVvVRnUSIYTlqJxdrTWAM1UnEUJYz9S4jQZACkAIB2JTCkAIx9IIbTRmbqk6iBDCegxuqWmEVqqDCCGsx0CyxnIJUAhHIkZzDUCi6iBCCCWSpQCEcCpCkhSAEM6VpEFWAhbCqWQMQAjHYrjlCEAIpyJoGuQBNyGcStMgs6kK4VQuDYBMohAAU3UAUSfTNGWy1sBoGmRppYD4Kn0yfXqEKj/ti734q0QNmhwBBMjrrWymOoOoXUVlRVPVGaKMKWMAAaqo9HU2/aZPdQ5xLp+v6nRlpb+T6hxRxisFELj44g3b16sOIc61fsP2byCrWwXqlAZAPs0C9OHHX1aqziDO9d6S1XIqGzivBuCo6hTR5sDBo5cfOFS2S3UO8YPv9x3ZeeToiUEXf6U4B/1wBCAFECiC+7l/LSpjZrmCohgz8z+fX3wKckNb4PiHAihTnSManTxVPqBg8dJlqnM43dzXP1p+yltxieocUcqrsRwBNNqKlRuu+Wx58ReqczjVe0tWfb5m7dYhqnNEKwaOyylAcFxvvLX88vmLPyuU0wHrMDO/mP/+siUff3UVALn7r/EOuDVQGcvNgMFwff7Fxuyyo6cKf37v6GzVYexu+87vt7zw8nv+8vLKoaqzRDuNsc9tEh8hef8Hbcv2PW1VZ7CzNWu/KXrr3c9x/OTp/pABv5Awifa7NdAeOQIInlFldD527OSB5ORmstBKiPl8/tNzX/tPdwbL5DWhRPy9RgbvVJ3DLorWbftWdQY7Klz+9Tp584ce+V37tQQN30GeCAyJ1V+WqI5gS0tXbIhXncGGONFl7Nfy8/UKAPtVp7GD/YfK+siDQqF17Jj38MmT3r6qc9gO40h+vl5xZjBll8ostsFI3lCyY4PqGHby4cerNwNwqc5hO4QtwI+jqbvUJbGXjwuLvKoz2Mmar7fIoGp4fAOcKQCCDASGyJ7vDvb3VfmlBEJg564D23w+f1fVOeyIqEYBsEmb1caxDwaaL12+7mvVOexg/uLPSlVnsCuz5hEAg4rVxrGXz5YWyVoLQTp23Ht4377D8ohvmLhM12agugC00z2+AVCuNJGNnPJWDDhQWvad6hzRbMHiz0oAyCSf4VFpnu6+C6gugIKCHAOMTSoT2Qy9/8Gq7apDRCufz1++adMuecQ3fLYUFOQYQM17qgnrlMWxofUbt3eXewIa54OPVq9lcIrqHDb21Zn/qFkAMg4QQqbJWR99+tUq1TmiDTNz4fLidqpz2BkTzv5eni0AZk2OAELso0+L2jCzLCYUgE8+K1ptGKYUQBixgS/P/PfZAqiMNddCZggOKb/f32nlqo1fXvyVAgAMv+l778NVrVXnsDnvkU44+9DK2QJ45wX9NAhr1WSyrzff/UJWEmqggjeXrzZMU+ZVCK81hbp+dgr1cydWYCy1PI7NVVT6eq/fuKNIdY5I5y2vPLly9freqnPYHfOPA4DAeQXAJskst2Ew7/WPY2XOwPrNe3VJETNSVeewO2I6ZxLbcwrA545fAZbFQkOtosLXZ9nn62X24DocPXby4KbNuy9TncMBjBh/bGHNL5xTAG+//OBJQC4HhsMb7yxva8h9AbX63xff3gFAbp8Ov9WvvvrwOeuAXDC5ImkyDhAOpsHt3nh7uRwFnGdN0bZ1Bw4cvVJ1Dicg4OPzv3ZBATDTEmviOM+yLzZccspbcUR1jkhRUenzzpv/UQvVOZzCJHx0/tcuKICU2MxCAMesCOQ8nPb///2mPHNR7fkX3yoyDTNLdQ6HOHa4PS64J+WCAnjhhZ9VAZCjgDDZs7d0yLoNOxw/X8A3W/Zs2r7zwNWqczjIpzWv/59R1wILb4c5jJNR/rwPkv2GUak6iCp+w6h8YdY78ZAFPixDRLW+p2v9B4jxxX0AoCqsiRzMMMyOc+Z96NgBwRdnvbfa7zc6q87hIFXuytiGF0D1pYLlYY3kcMXrdwzZ8u1ex40HrC3etq7km93XqM7hMB+ff/nvjDoPwYjxVvjyCBDcz7/4dnxVlXFKdRSrHD/uLZ3zypI2kEN/SxGwqK7v1fkP4TdiCuSuwPDy+43Of/tngSOeE/AbZtWTf371ADOnqc7iMFXswpt1fbPOAlg8b/p+aBfeOCBC67u9pUOXfPzVCtU5wu1v/1y46nRFhUzzZb1PCl7Sj9b1zXoPxZgxJ/R5xPneW7JqgGnjqwJF675dt/u7g0NU53AiJlpQ3/frLYCmwJuQm4KskGiCDNUhwuW0t8K25RbRGKd8FL+wvpfUWwD5+XoFMerdgBAiMjHhteoH/Op00dFYkzQ5DRAiCpGJFy/2mosWwML8R1cA2BaSREIIq6wvmKNfdD7KhlyPZWL8IwSBhBBWIfy7IS9r0A0ZFa6EWQBOBBVICGGV8pjKuFca8sIGFUD1QMKsoCIJIaxBmFvXrb/na/gtmYbrbwBse6lKCJtgze/6n4a+uMEFUDD3DzsBvN+oSEIIq7w9f+4fNjf0xQE9lMFMfws8jxDCMhqeCezlAVg4e8YnAFYHFEgIYZWvCl7WA3quJODHMgmYGejPCCHCj4GnAv2ZgAtgQb7+PnDh5IJCCKVKyNsr4Dk8GjUxAwF5jfk5IUR4MPCHgoKcgK/SNaoAqo8CZCxAiMiwdmG+/kZjfrDRUzPJWEBIGS6N4lSHCBfNBVKdwc6Y8QiARi0+2+gCqD4KkIlDQ4KOEZFLdYpwad4s0bblFgEKF87WL1jxp6GCm5yRtd8AMIPahkBcrOuQ6gzhlJTUtKnqDHbFhOnB/HxQBVAw+9G1xJgdzDYEkJmZdlh1hnBqnZnWHkC56hw2tHjhLD2o9SWCnp7Zb8RMB8MxU1uHw6X9u9l6mmzNpbkSm8TJnBKhVe4CfhvsRoL+xVs8b/p+IjwZ7HYczHvV5b37qw4RbgMHdD+uOoOtMJ56PV/fFexmQvLJ0wR4FsCuUGzLaTp2aLUmNi4mUXWOcLt+5KBeAHyqc9jEjkTCn0KxoZAUQH6+XkHAb0KxLYepmDj+ekeskde8WWJap46tVqnOYQuM3+Tn6xWh2FTIzj0X5OtvElAQqu05wWWDeq5MTWnWRnUOq+TefWNPENU7S624CMIHBbP1kK3eHdLBJwZ+BaDOVUjEjxIT4taNz7nWUYtlJCc1aXHzjVduUJ0jajFOwe/6ZSg3GdICKMjXDyAEI5N253a7d0x/aEIbTSO36ixWGzn80qs6tsuUG8gagQkPVk/MEzIhv/uspLhwXe/+2VcBcMS5baBiYmO2/v53dzdJap6YoTqLKlcM7tV23fpvV57ylrdVnSVqED5bmK/fH+rNhuP6M7uAaQC8Ydh2VGuRnrTy8RlTslJTmmWpzqISEWkPPXDXFX37dC5EI+9hd5QfDv2nIAx/V2G5/3xjceGxXgOGHyFgVDi2H21cmrY/5/Zhm+4ed92VMW5XrOo8kYCIaGD/rh1apiev3VSyq8pkTladKVIx4TcL58wIy0rdYX1Ky5OrLwJwezj3EckIODF4UI+inDEjLo+JcSWozhOp/IZRufCNpStXfVnSxzQ5XXWeCPNpQb4+EmE6UgrrE2jd+md/5ALGAXBau1e1b5fxxQO/vjP1skt79HK5tBjVgSKZpmnuPr06dhgxbCBXVPpW7dl7KJ4Z8gARUOrScP3GrwvDduk07M9peybr18BEIcJcNhGCW6YnrZo2eXTrli1T2qkOE618Pr/37fc/X7viiw3dTZOdOlhqEtGNC2bNWBLOnVgyUUNOrq4zMMOKfanSJD5uQ+6E69GjW/tLVGexCycXAQN/XJivB/Wob0NYUgAezwIXEks+BTDUiv1ZKSbGvdVz27BDVwzudY3qLHbl8/m9b7yz4usvVm3sycxpqvOEHWNFaUcML9R1f7h3ZdlUTePufSLD76/6CoAtrv1qGh24Nnvgtpt+euVVmmbf2XwiiUOOCMoMl3vA4pd+v9uKnVk6V9uYCTMHaJq5AkATK/cbSgTy9u/bac3d464fLCP7ati4CAw2afTCOTM+sGqHlk/WOHZi3nginmf1fkOgqn27jFVTc0f1bN68iVyqigB2KwIGfrkwX/+XlftUMlvr2In6n4nwgIp9N4KM7Ec4mxTBSwX5+r1W71TJuWvObdmflB7DZQC6qth/QzWJj9swdfJNh26/ZdiliYkJSarziNq5XFpsrx4d2o8YNpCi9D6CZfDizpKSwoAX9giWsvnab83Vk2OAZQAi7rKZO8a9Lee2YQdlZD86RdlVg21w4YqCl3Qlj9ErXbDBM+Hx1tD8nwNorzLHGS5N2/+TkYO2/nTk4GtkZD/6RUERlGomrpk/R9+qKoDyFVs8U/QuMPA5gJaqMsjIvr1F6BjBCbA2omD2o2tVhlBeAABwR+7My0w2PwVZft4mI/sOEkFF4ANoVEF+eJ7wC0REFAAAjJ2Ydy0Rvw/AisdlZWTfwRQXgQHCnQWz9IUW77dWEVMAAJAzKW8cM89FGK9OJCbGF02ecKO7a+fWfcO1DxEdFIwRMAH3LsjXX7ZgXw0SUQUAVJeAyXNACOl8eTKyL+piUREwg369MH/Gc2HafqNEXAEAgGeSPhaMVwEE/Ry93LMvGiqMpwYMwq8KZun/COE2QyIiCwAIvgRkZF80VoiLwCRgaiQd9tcUsQUAADkT88Yw8WsIrAR+GNmfPKpn86Yysi8aLwRFYBDRlAWzZkTsCtoRXQAAkJObN5rBr6MBTxCmpyWt/vnUm7Napifb4pFjERl8Pr930ZtL16z8suQSAKkN+iGGnwn3LMzXXw9vuuBEfAEAgGeCPhga3kEdNwsR0cGxtw7bOeTqS66wOJpwkNOnK4/PfmVJ8eYtu69E/ZervWC6o2D2jPesytZYUVEAAHDHBL2bqeEDAJ1qfr1ju8zlv/jZLQPj42Jtv8KuiAy79xza9vyLb3tPectrW9Z9v0YYNX+WXmR5sEaImgIAzs4q9B6ASwFU3nDd5V/dcN1guawnLMfMvOitZcuXrVh/Jc6MURE2G5r7Bqtm8wmFqCoAAPDcpzeNN2NfnjZldJ8uHbN6qs4jnG1Dyc51L+W/l2mavBUu3Krqqb7GiroCAIA9e/YkxCQkvMCgu1VnEaL08ImXn31q9i/z8/UK1VkCFZUFcMa+0qPTiPgfCMENQ0I0ggHG45npqXlEFJVrHEZ1AQDAvkNlQ0kzC6DwcWLhSEeZMC4rLe0j1UGCEfUFAAAHDx7rZLqM+QAGqc4i7I8IxeR3jcnISN6hOkuwwrE8uOUyMpJ3ZKalXglGHgBTdR5hZzTXrKy82g5vfsAmRwA1HSg9OpqJZwGIxCmgRPQ6DsK0VmlpC1QHCSXbFQAAfH/kSFsNmAe231JkQgHCchMY3zotbY/q8857xQAAA21JREFUKKFmywIAAGam/YfLphLxswDkLkHRGBUA6ZlpKc8QkeVTdlvBtgVwxsGDxzqZbmOWHA2IAK1m8KSs9PTNqoOEk+0LAACY2XXgSNkDAM8AIHMDiPpUADQjMy3lL3b91K/JEQVwRvXRwHNg3Kg6i4hE9BnD/KXdP/VrclQBnFF9peAfAGRGYAEA+wF+qFV6+hzVQaxmi/sAApXZIvUdN5t9QPgLAJ/qPEKZKjCedbPZ3YlvfsChRwA17Tt6tB2ZeBzguyF/H47BwH+I8P9apaVtUp1FJfmFr7b/8OHBYPoLCDK/gL19xab2QFbLlGWqg0QCKYAamJkOHD06BoxHEYGrFougbAJBz0xNXRStT+6FgxRALZiZDh4uG8Vk5gE0QHUeEZQSgJ/OTEt7xQmX9QIlBVAPZtYOHD06FiamgyBLiUWXDSA8npmaupCI5AGxOkgBNNC+o0evIdN8EKCbIH9vEYsYnwP0dEZ6yrtyqH9x8oscoP1HjvQG478AHg9QnOo8AgC4kpnmaS76n8zU1I2q00QTKYBG2nfiRDqqqiYQYyqAHqrzONRWMP4Nf+zsVq2alaoOE42kAEJgX2nppZqmTWPG3WjACkYiGFwJ0Nsa+IWWaWmfyGF+cKQAQmhnWVlygmnebjLuJGAEAFmNODQMBj7TCPMrXa5F7ZOTy1QHsgspgDA5ePBgBrtcOSboTgKugENvuw6CCcYXIH5dM4yFGRkZB1UHsiMpAAvsO3EinaqqhoNpNMA3A0hSnSlCnQb4U2btnRgY77Zo0WKf6kB2JwVgsW3bOC4x9egwMnE9iLIB7gfnnioYAK0Dc6Gm4cPDqalLexPJw1kWkgJQbGdZWXKCn4cAPJyJhgLcF/Zd6KQKwDowlhGosNxNyzumpBxTHcrJpAAizM6dO+MTmjXrx8AggC7DD2sddAfgVhwtUAaAzQDWALyGgDXlJ0+u69ixY9Qtn2VnUgBRYBNzbFpZWTdm7sHM3QH0ImjdwdwehHTF8Y4AtIthbgFQQkRbiGjLySMpW7t2pUrF2cRFSAFEuT179iRo8fHtXERtGGjDQBsiSgEjlUApDDMFTCnQ0BSMGABNq380Dj/es1AO4MwnsxcEH0ycAnEZQStjcBkYZUx8lIC9BOw1mPeaFRXftW3bttzqP7MInf8D58eX1U6GHiMAAAAASUVORK5CYII="));

MemoryImage userAvatarBackup = MemoryImage(base64Decode(
    "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"));

double p_longitude = 0.0;
double p_latitude = 0.0;

CookieJar cookieJar = CookieJar();

void clearAll() {
  userId = "";
  userName = "";
  userEmail = "";
  userPhone = "";
  userType = ""; // user type to indicate the type of user he is
  userImageStr = "";
  userDefaultRouteId = "";
  userDefaultRouteName = "";
  userDefaultStationId = "";
  userDefaultStationName = "";
  teacherDepartment = "";
  teacherDesignation = "";
  teacherResidence = "";
  staffRole = "";
  serverAddr = 'http://3.141.62.8:6969';
  serverIp = '$serverAddr/api/';
  runningTripId = "";
  trackingTripId = "";
  userAvatar = userAvatarBackup;
  if (positionStream != null) positionStream!.cancel();
}
