package upswake

import rego.v1

default wake := false

wake if {
    input[i].Name == "ups"
    input[i].Variables[j].Name == "battery.charge"
    input[i].Variables[j].Value >= 80
    input[i].Variables[k].Name == "ups.status"
    contains(input[i].Variables[k].Value, "OL")
    not contains(input[i].Variables[k].Value, "OB")
}