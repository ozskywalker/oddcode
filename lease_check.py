#!/usr/bin/python3

lease_period = int(input("How many months is the lease for (default=36 months)? ") or "36")
down_payment = int(input("What's the down payment? "))
first_payment = int(input("What's the first month's payment? "))
acquisition_fee = int(input("What's the acquisition fee? "))
msrp = int(input("What's the MSRP of the vehicle? "))

real_down_payment = (down_payment - first_payment + acquisition_fee)
real_monthly_payment = (real_down_payment / lease_period) + first_payment
value = (real_monthly_payment / msrp) * 10000

print("\n[*] Real down payment is %d / month" % (real_down_payment))
print("[*] Real monthly payment is %.2f/mth" % (real_monthly_payment))
print("[*] Value is %.2f/month per $10k of vehicle\n" % (value))

if value <= 105:
    print("*** Great deal under $105/mth/10k ***")
elif value <= 125:
    print("*** Under $125/mth/10k - considered good! ***")
else:
    print("!!! Over $125/mth/10k - may want to reconsider... !!!")