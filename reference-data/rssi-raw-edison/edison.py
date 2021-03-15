import Ed
Ed.EdisonVersion = Ed.V2
Ed.DistanceUnits = Ed.CM
Ed.Tempo = Ed.TEMPO_MEDIUM

# Calibration data for mapping Edison drive distance 
# to cable cart movement distance. This is obtained
# by running practical experiments to measure how far
# the cart moves in your test environment for a fixed
# Edison drive distance.
#
# For example, set Edison to drive for 200 cm ...
#
# Ed.DriveLeftMotor(Ed.BACKWARD, Ed.SPEED_5, 200)
#
# ... then measure actual distance travelled by
# the cable cart, so if Edison 200cm = Cart 128cm,
# then Cart 1cm = 200 / 128 = Edison 1.5625cm
#
# Cart 20cm = 20 x 1.5625 = Edison 31.25cm
# Cart 25cm = 25 x 1.5625 = Edison 39cm

# Define sampling schedule
sampleDuration = 240    # Sample duration in seconds (4 minutes = 4 x 60 = 240 seconds)
sampleDistanceStep = 2  # Sample resolution in Edison drive distance (Cart 1cm = Edison 2cm)
sampleSteps = 340       # Number of sample periods (Cart 1cm x 340 steps = 340cm total range)

# Sample duration is split into shorter wait time periods
# because Edison will power off automatically if Ed.TimeWait()
# is set to a large value. Nested loops are also not currently
# supported, thus a simple way forward is to divide sample
# duration into 20 shorter time periods to ensure Edison stays
# awake throughout the sample duration.

waitTime = sampleDuration / 20

# Wait one minute before starting because the Edison is
# attached to the cable in the current test environment,
# so pressing play will naturally generate movement for
# the Edison as well as the carts, so wait one minute to
# let the movement settle to ensure the inertia sensor
# registers a clean movement signal for timestamping the
# start event.
Ed.PlayBeep()
Ed.TimeWait(10, Ed.TIME_SECONDS)
Ed.PlayBeep()
Ed.TimeWait(10, Ed.TIME_SECONDS)
Ed.PlayBeep()
Ed.TimeWait(10, Ed.TIME_SECONDS)
Ed.PlayTone(Ed.NOTE_A_7, Ed.NOTE_HALF)
Ed.TimeWait(10, Ed.TIME_SECONDS)
Ed.LeftLed(Ed.ON)

# Run sampling schedule according to parameters
for i in range(sampleSteps):
    # Move cable cart along by one distance unit at a reasonably
    # fast speed to ensure the inertia sensor registers a clear
    # signal for the movement event. 
    #Ed.PlayTone(Ed.NOTE_B_7, Ed.NOTE_HALF)
    Ed.DriveLeftMotor(Ed.BACKWARD, Ed.SPEED_5, sampleDistanceStep)
    #Ed.PlayTone(Ed.NOTE_C_7, Ed.NOTE_HALF)
    # Wait for sample duration. This would normally be implemented
    # as a single call to Ed.TimeWait() if it supported longer 
    # time periods, or a nested loop which is currently unsupported
    # 0
    Ed.TimeWait(waitTime, Ed.TIME_SECONDS)
    Ed.TimeWait(waitTime, Ed.TIME_SECONDS)
    Ed.TimeWait(waitTime, Ed.TIME_SECONDS)
    Ed.TimeWait(waitTime, Ed.TIME_SECONDS)
    Ed.TimeWait(waitTime, Ed.TIME_SECONDS)
    # 5
    Ed.TimeWait(waitTime, Ed.TIME_SECONDS)
    Ed.TimeWait(waitTime, Ed.TIME_SECONDS)
    Ed.TimeWait(waitTime, Ed.TIME_SECONDS)
    Ed.TimeWait(waitTime, Ed.TIME_SECONDS)
    Ed.TimeWait(waitTime, Ed.TIME_SECONDS)
    # 10
    Ed.TimeWait(waitTime, Ed.TIME_SECONDS)
    Ed.TimeWait(waitTime, Ed.TIME_SECONDS)
    Ed.TimeWait(waitTime, Ed.TIME_SECONDS)
    Ed.TimeWait(waitTime, Ed.TIME_SECONDS)
    Ed.TimeWait(waitTime, Ed.TIME_SECONDS)
    # 15
    Ed.TimeWait(waitTime, Ed.TIME_SECONDS)
    Ed.TimeWait(waitTime, Ed.TIME_SECONDS)
    Ed.TimeWait(waitTime, Ed.TIME_SECONDS)
    Ed.TimeWait(waitTime, Ed.TIME_SECONDS)
    Ed.TimeWait(waitTime, Ed.TIME_SECONDS)

# Rewind cable cart back to start ready for the next run
#Ed.PlayTone(Ed.NOTE_D_7, Ed.NOTE_HALF)
Ed.DriveLeftMotor(Ed.FORWARD, Ed.SPEED_5, sampleSteps * sampleDistanceStep)
#Ed.PlayTone(Ed.NOTE_E_7, Ed.NOTE_HALF)

# Wait for sampling at 0cm
# 0
Ed.TimeWait(waitTime, Ed.TIME_SECONDS)
Ed.TimeWait(waitTime, Ed.TIME_SECONDS)
Ed.TimeWait(waitTime, Ed.TIME_SECONDS)
Ed.TimeWait(waitTime, Ed.TIME_SECONDS)
Ed.TimeWait(waitTime, Ed.TIME_SECONDS)
# 5
Ed.TimeWait(waitTime, Ed.TIME_SECONDS)
Ed.TimeWait(waitTime, Ed.TIME_SECONDS)
Ed.TimeWait(waitTime, Ed.TIME_SECONDS)
Ed.TimeWait(waitTime, Ed.TIME_SECONDS)
Ed.TimeWait(waitTime, Ed.TIME_SECONDS)
# 10
Ed.TimeWait(waitTime, Ed.TIME_SECONDS)
Ed.TimeWait(waitTime, Ed.TIME_SECONDS)
Ed.TimeWait(waitTime, Ed.TIME_SECONDS)
Ed.TimeWait(waitTime, Ed.TIME_SECONDS)
Ed.TimeWait(waitTime, Ed.TIME_SECONDS)
# 15
Ed.TimeWait(waitTime, Ed.TIME_SECONDS)
Ed.TimeWait(waitTime, Ed.TIME_SECONDS)
Ed.TimeWait(waitTime, Ed.TIME_SECONDS)
Ed.TimeWait(waitTime, Ed.TIME_SECONDS)
Ed.TimeWait(waitTime, Ed.TIME_SECONDS)
# LED off to indicate completion of 0cm sampling
Ed.LeftLed(Ed.OFF)
