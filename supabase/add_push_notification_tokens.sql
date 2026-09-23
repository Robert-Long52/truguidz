-- Where a device's APNs token lives so a future send-push-notification
-- function (triggered off new bookings/status changes/messages) knows
-- where to actually deliver to. Only ever written by the device itself
-- right after registering with APNs (see PushNotificationService.swift),
-- so the existing "Users can update their own profile" RLS policy is
-- exactly the right amount of access -- no separate policy needed.
alter table public.profiles
    add column if not exists device_push_token text;
alter table public.profiles
    add column if not exists device_push_platform text;
