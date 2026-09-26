/// Send single-response USSD requests on Android through the official
/// `TelephonyManager.sendUssdRequest` API, with dual-SIM targeting, typed
/// errors, a dialer fallback and helpers to read amounts from replies.
library;

export 'src/amounts.dart';
export 'src/carrier_presets.dart';
export 'src/sim_card.dart';
export 'src/ussd_code.dart';
export 'src/ussd_exception.dart';
export 'src/ussd_permissions.dart';
export 'src/ussd_response.dart';
export 'src/ussd_session.dart';
