import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';

/// Country → State → City cascading picker used on the Complete Profile
/// and Edit Profile screens.
///
/// Each field opens its own full-height, searchable bottom sheet
/// ([_LocationSearchSheet]) instead of an inline Material dropdown, so a
/// long list (all ~195 countries, or a country with dozens of states)
/// is never clipped down to just a couple of visible rows — the sheet
/// gets a fixed height and a real scrollable [ListView.builder], so
/// every entry is reachable by scrolling or by typing to filter.
///
/// [_kAllCountries] covers every country. [_kLocationData] additionally
/// supplies states/provinces and cities for the countries listed there;
/// for any country not in that map (or a state with no city list), the
/// state/city fields fall back to a free-text entry so nothing is ever
/// blocked by a gap in the data.
class CascadingLocationPicker extends StatefulWidget {
  final String? initialCountry;
  final String? initialState;
  final String? initialCity;

  /// Fired on every change with the current (country, state, city) triple.
  final void Function(String? country, String? state, String? city) onChanged;

  const CascadingLocationPicker({
    super.key,
    this.initialCountry,
    this.initialState,
    this.initialCity,
    required this.onChanged,
  });

  @override
  State<CascadingLocationPicker> createState() => _CascadingLocationPickerState();
}

class _CascadingLocationPickerState extends State<CascadingLocationPicker> {
  late String? _country;
  late String? _state;
  late String? _city;

  late final TextEditingController _stateFallbackController;
  late final TextEditingController _cityFallbackController;

  @override
  void initState() {
    super.initState();
    _country = widget.initialCountry;
    _state = _statesFor(_country).containsKey(widget.initialState) ? widget.initialState : null;
    _city = _citiesFor(_country, _state).contains(widget.initialCity) ? widget.initialCity : null;

    _stateFallbackController = TextEditingController(
      text: _statesFor(_country).containsKey(widget.initialState) ? '' : (widget.initialState ?? ''),
    );
    _cityFallbackController = TextEditingController(
      text: _citiesFor(_country, _state).contains(widget.initialCity) ? '' : (widget.initialCity ?? ''),
    );
  }

  @override
  void dispose() {
    _stateFallbackController.dispose();
    _cityFallbackController.dispose();
    super.dispose();
  }

  Map<String, List<String>> _statesFor(String? country) =>
      country == null ? const {} : (_kLocationData[country] ?? const {});

  List<String> _citiesFor(String? country, String? state) =>
      state == null ? const [] : (_statesFor(country)[state] ?? const []);

  void _emit() {
    final state = _state ?? _emptyToNull(_stateFallbackController.text);
    final city = _city ?? _emptyToNull(_cityFallbackController.text);
    widget.onChanged(_country, state, city);
  }

  String? _emptyToNull(String v) => v.trim().isEmpty ? null : v.trim();

  Future<void> _pickCountry() async {
    final picked = await _LocationSearchSheet.show(
      context,
      title: 'Select country',
      options: _kAllCountries,
      current: _country,
    );
    if (picked == null) return;
    setState(() {
      _country = picked;
      _state = null;
      _city = null;
      _stateFallbackController.clear();
      _cityFallbackController.clear();
    });
    _emit();
  }

  Future<void> _pickState() async {
    final states = _statesFor(_country).keys.toList();
    if (states.isEmpty) return;
    final picked = await _LocationSearchSheet.show(
      context,
      title: 'Select state / province',
      options: states,
      current: _state,
    );
    if (picked == null) return;
    setState(() {
      _state = picked;
      _city = null;
      _stateFallbackController.clear();
      _cityFallbackController.clear();
    });
    _emit();
  }

  Future<void> _pickCity() async {
    final cities = _citiesFor(_country, _state);
    if (cities.isEmpty) return;
    final picked = await _LocationSearchSheet.show(
      context,
      title: 'Select city',
      options: cities,
      current: _city,
    );
    if (picked == null) return;
    setState(() {
      _city = picked;
      _cityFallbackController.clear();
    });
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final states = _statesFor(_country);
    final cities = _citiesFor(_country, _state);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PickerField(
          label: 'Country',
          value: _country,
          hint: 'Select country',
          icon: Icons.public_rounded,
          onTap: _pickCountry,
        ),
        const SizedBox(height: AppSpacing.md),
        _PickerField(
          label: 'State / Province',
          value: _state,
          hint: states.isEmpty ? 'No list for this country — type below' : 'Select state',
          icon: Icons.map_outlined,
          enabled: states.isNotEmpty,
          onTap: _pickState,
        ),
        if (states.isEmpty && _country != null) ...[
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _stateFallbackController,
            decoration: const InputDecoration(
              labelText: 'State / Province (type it)',
              prefixIcon: Icon(Icons.edit_location_alt_outlined, color: AppColors.subtitle, size: 20),
            ),
            onChanged: (_) => _emit(),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        _PickerField(
          label: 'City',
          value: _city,
          hint: cities.isEmpty ? 'No list for this state — type below' : 'Select city',
          icon: Icons.location_city_rounded,
          enabled: cities.isNotEmpty,
          onTap: _pickCity,
        ),
        if (cities.isEmpty && _state != null) ...[
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _cityFallbackController,
            decoration: const InputDecoration(
              labelText: 'City (type it)',
              prefixIcon: Icon(Icons.edit_location_alt_outlined, color: AppColors.subtitle, size: 20),
            ),
            onChanged: (_) => _emit(),
          ),
        ],
      ],
    );
  }
}

/// Read-only-looking tap target styled like a [DropdownButtonFormField]
/// (same label/icon/border conventions as the rest of the app's inputs)
/// that opens [_LocationSearchSheet] instead of an inline dropdown.
class _PickerField extends StatelessWidget {
  final String label;
  final String? value;
  final String hint;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _PickerField({
    required this.label,
    required this.value,
    required this.hint,
    required this.icon,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: enabled ? AppColors.primary : AppColors.subtitle, size: 20),
        enabled: enabled,
      ),
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                value ?? hint,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14.5,
                  color: value == null ? AppColors.subtitle : AppColors.text,
                ),
              ),
            ),
            Icon(Icons.arrow_drop_down_rounded,
                color: enabled ? AppColors.subtitle : AppColors.border),
          ],
        ),
      ),
    );
  }
}

/// Full-height, searchable picker sheet. Always renders its list in a
/// bounded [SizedBox] + [ListView.builder], so no matter how long
/// [options] is, the whole list is reachable by scrolling — this is the
/// piece that guarantees "more than 1-2 items show up".
class _LocationSearchSheet extends StatefulWidget {
  final String title;
  final List<String> options;
  final String? current;

  const _LocationSearchSheet({required this.title, required this.options, required this.current});

  static Future<String?> show(
    BuildContext context, {
    required String title,
    required List<String> options,
    required String? current,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _LocationSearchSheet(title: title, options: options, current: current),
    );
  }

  @override
  State<_LocationSearchSheet> createState() => _LocationSearchSheetState();
}

class _LocationSearchSheetState extends State<_LocationSearchSheet> {
  late List<String> _filtered;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filtered = widget.options;
  }

  void _onSearch(String query) {
    setState(() {
      _filtered = query.trim().isEmpty
          ? widget.options
          : widget.options.where((o) => o.toLowerCase().contains(query.trim().toLowerCase())).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Fixed proportion of the screen so the sheet — and therefore the
    // list inside it — always has real, generous height to scroll in,
    // regardless of how many options there are.
    final sheetHeight = MediaQuery.of(context).size.height * 0.75;

    return SafeArea(
      child: SizedBox(
        height: sheetHeight,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(widget.title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.text)),
                  Text('${_filtered.length} of ${widget.options.length}',
                      style: const TextStyle(fontSize: 12.5, color: AppColors.subtitle)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: TextField(
                controller: _searchController,
                autofocus: false,
                onChanged: _onSearch,
                decoration: const InputDecoration(
                  hintText: 'Search…',
                  prefixIcon: Icon(Icons.search_rounded, color: AppColors.subtitle, size: 20),
                ),
              ),
            ),
            Expanded(
              child: _filtered.isEmpty
                  ? const Center(
                      child: Text('No matches', style: TextStyle(color: AppColors.subtitle)))
                  : ListView.builder(
                      // Always a real scrollable list — every filtered
                      // entry is laid out and reachable, never capped.
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _filtered.length,
                      itemBuilder: (context, index) {
                        final option = _filtered[index];
                        final selected = option == widget.current;
                        return ListTile(
                          title: Text(option,
                              style: TextStyle(
                                  color: selected ? AppColors.primary : AppColors.text,
                                  fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
                          trailing: selected
                              ? const Icon(Icons.check_rounded, color: AppColors.primary, size: 18)
                              : null,
                          onTap: () => Navigator.of(context).pop(option),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Every country (all UN member states plus commonly-listed observer
/// states), used for the top-level Country field. Kept as a flat list
/// here since — unlike states/cities below — a full, correct country
/// list is small and stable enough to maintain directly.
const List<String> _kAllCountries = [
  'Afghanistan', 'Albania', 'Algeria', 'Andorra', 'Angola', 'Antigua and Barbuda', 'Argentina',
  'Armenia', 'Australia', 'Austria', 'Azerbaijan', 'Bahamas', 'Bahrain', 'Bangladesh', 'Barbados',
  'Belarus', 'Belgium', 'Belize', 'Benin', 'Bhutan', 'Bolivia', 'Bosnia and Herzegovina',
  'Botswana', 'Brazil', 'Brunei', 'Bulgaria', 'Burkina Faso', 'Burundi', 'Cabo Verde', 'Cambodia',
  'Cameroon', 'Canada', 'Central African Republic', 'Chad', 'Chile', 'China', 'Colombia',
  'Comoros', 'Congo (Congo-Brazzaville)', 'Costa Rica', 'Croatia', 'Cuba', 'Cyprus', 'Czechia',
  'Democratic Republic of the Congo', 'Denmark', 'Djibouti', 'Dominica', 'Dominican Republic',
  'Ecuador', 'Egypt', 'El Salvador', 'Equatorial Guinea', 'Eritrea', 'Estonia', 'Eswatini',
  'Ethiopia', 'Fiji', 'Finland', 'France', 'Gabon', 'Gambia', 'Georgia', 'Germany', 'Ghana',
  'Greece', 'Grenada', 'Guatemala', 'Guinea', 'Guinea-Bissau', 'Guyana', 'Haiti', 'Honduras',
  'Hungary', 'Iceland', 'India', 'Indonesia', 'Iran', 'Iraq', 'Ireland', 'Israel', 'Italy',
  'Jamaica', 'Japan', 'Jordan', 'Kazakhstan', 'Kenya', 'Kiribati', 'Kosovo', 'Kuwait',
  'Kyrgyzstan', 'Laos', 'Latvia', 'Lebanon', 'Lesotho', 'Liberia', 'Libya', 'Liechtenstein',
  'Lithuania', 'Luxembourg', 'Madagascar', 'Malawi', 'Malaysia', 'Maldives', 'Mali', 'Malta',
  'Marshall Islands', 'Mauritania', 'Mauritius', 'Mexico', 'Micronesia', 'Moldova', 'Monaco',
  'Mongolia', 'Montenegro', 'Morocco', 'Mozambique', 'Myanmar', 'Namibia', 'Nauru', 'Nepal',
  'Netherlands', 'New Zealand', 'Nicaragua', 'Niger', 'Nigeria', 'North Korea', 'North Macedonia',
  'Norway', 'Oman', 'Pakistan', 'Palau', 'Palestine', 'Panama', 'Papua New Guinea', 'Paraguay',
  'Peru', 'Philippines', 'Poland', 'Portugal', 'Qatar', 'Romania', 'Russia', 'Rwanda',
  'Saint Kitts and Nevis', 'Saint Lucia', 'Saint Vincent and the Grenadines', 'Samoa',
  'San Marino', 'Sao Tome and Principe', 'Saudi Arabia', 'Senegal', 'Serbia', 'Seychelles',
  'Sierra Leone', 'Singapore', 'Slovakia', 'Slovenia', 'Solomon Islands', 'Somalia',
  'South Africa', 'South Korea', 'South Sudan', 'Spain', 'Sri Lanka', 'Sudan', 'Suriname',
  'Sweden', 'Switzerland', 'Syria', 'Taiwan', 'Tajikistan', 'Tanzania', 'Thailand',
  'Timor-Leste', 'Togo', 'Tonga', 'Trinidad and Tobago', 'Tunisia', 'Turkey', 'Turkmenistan',
  'Tuvalu', 'Uganda', 'Ukraine', 'United Arab Emirates', 'United Kingdom', 'United States',
  'Uruguay', 'Uzbekistan', 'Vanuatu', 'Vatican City', 'Venezuela', 'Vietnam', 'Yemen', 'Zambia',
  'Zimbabwe',
];

/// State/city breakdown for the countries picgallery is most likely to
/// launch in first. Not exhaustive for every one of the 195 countries
/// above — any country missing here (or a state with no city list)
/// simply falls back to the free-text field, so nothing is ever
/// blocked by a gap in this data. Extend freely.
const Map<String, Map<String, List<String>>> _kLocationData = {
  'India': {
    'Andhra Pradesh': ['Visakhapatnam', 'Vijayawada', 'Guntur'],
    'Delhi': ['New Delhi'],
    'Gujarat': ['Ahmedabad', 'Surat', 'Vadodara', 'Rajkot', 'Bhavnagar', 'Amreli'],
    'Karnataka': ['Bengaluru', 'Mysuru', 'Mangaluru', 'Hubballi'],
    'Kerala': ['Kochi', 'Thiruvananthapuram', 'Kozhikode'],
    'Madhya Pradesh': ['Bhopal', 'Indore', 'Gwalior', 'Jabalpur'],
    'Maharashtra': ['Mumbai', 'Pune', 'Nagpur', 'Nashik'],
    'Punjab': ['Ludhiana', 'Amritsar', 'Jalandhar'],
    'Rajasthan': ['Jaipur', 'Udaipur', 'Jodhpur'],
    'Tamil Nadu': ['Chennai', 'Coimbatore', 'Madurai'],
    'Telangana': ['Hyderabad', 'Warangal'],
    'Uttar Pradesh': ['Lucknow', 'Kanpur', 'Varanasi', 'Agra'],
    'West Bengal': ['Kolkata', 'Howrah', 'Siliguri'],
  },
  'United States': {
    'California': ['Los Angeles', 'San Francisco', 'San Diego', 'Sacramento'],
    'Florida': ['Miami', 'Orlando', 'Tampa', 'Jacksonville'],
    'Illinois': ['Chicago', 'Aurora', 'Naperville'],
    'New York': ['New York City', 'Buffalo', 'Albany', 'Rochester'],
    'Texas': ['Houston', 'Austin', 'Dallas', 'San Antonio'],
    'Washington': ['Seattle', 'Spokane', 'Tacoma'],
  },
  'United Kingdom': {
    'England': ['London', 'Manchester', 'Birmingham', 'Liverpool'],
    'Scotland': ['Edinburgh', 'Glasgow', 'Aberdeen'],
    'Wales': ['Cardiff', 'Swansea'],
    'Northern Ireland': ['Belfast'],
  },
  'Canada': {
    'Ontario': ['Toronto', 'Ottawa', 'Mississauga'],
    'British Columbia': ['Vancouver', 'Victoria', 'Surrey'],
    'Quebec': ['Montreal', 'Quebec City'],
    'Alberta': ['Calgary', 'Edmonton'],
  },
  'Australia': {
    'New South Wales': ['Sydney', 'Newcastle', 'Wollongong'],
    'Victoria': ['Melbourne', 'Geelong'],
    'Queensland': ['Brisbane', 'Gold Coast', 'Cairns'],
    'Western Australia': ['Perth'],
  },
  'United Arab Emirates': {
    'Dubai': ['Dubai'],
    'Abu Dhabi': ['Abu Dhabi'],
    'Sharjah': ['Sharjah'],
  },
  'Pakistan': {
    'Punjab': ['Lahore', 'Faisalabad', 'Rawalpindi'],
    'Sindh': ['Karachi', 'Hyderabad'],
  },
  'Germany': {
    'Bavaria': ['Munich', 'Nuremberg'],
    'Berlin': ['Berlin'],
    'North Rhine-Westphalia': ['Cologne', 'Dusseldorf'],
  },
  'France': {
    'Ile-de-France': ['Paris'],
    'Provence-Alpes-Cote d\'Azur': ['Marseille', 'Nice'],
    'Auvergne-Rhone-Alpes': ['Lyon'],
  },
  'Singapore': {
    'Singapore': ['Singapore'],
  },
};