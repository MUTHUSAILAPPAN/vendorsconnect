import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../../services/street_service.dart';

/// A search bar that queries Nominatim and calls [onLocationSelected]
/// with the chosen [LatLng].
class PlaceSearchBar extends StatefulWidget {
  final void Function(LatLng location, String name) onLocationSelected;

  const PlaceSearchBar({super.key, required this.onLocationSelected});

  @override
  State<PlaceSearchBar> createState() => _PlaceSearchBarState();
}

class _PlaceSearchBarState extends State<PlaceSearchBar> {
  final streetService = StreetService();
  final controller = TextEditingController();
  final focusNode = FocusNode();

  List<PlaceResult> results = [];
  bool loading = false;
  bool _hasFocus = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    focusNode.addListener(() {
      setState(() => _hasFocus = focusNode.hasFocus);
      // Clear results when focus is lost
      if (!focusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) setState(() => results = []);
        });
      }
    });
  }

  @override
  void dispose() {
    controller.dispose();
    focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 3) {
      setState(() => results = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 600), () => search(value));
  }

  Future<void> search(String query) async {
    setState(() => loading = true);
    try {
      final found = await streetService.searchPlaces(query);
      if (!mounted) return;
      setState(() => results = found);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void selectResult(PlaceResult result) {
    controller.text = result.displayName.split(',').first;
    focusNode.unfocus();
    setState(() => results = []);
    widget.onLocationSelected(result.location, result.displayName);
  }

  void clearSearch() {
    controller.clear();
    setState(() => results = []);
    focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // ── Search field ──────────────────────────
        TextField(
          controller: controller,
          focusNode: focusNode,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: 'Search for a place or area…',
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: loading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: clearSearch,
                      )
                    : null,
            filled: true,
            fillColor: colorScheme.surface,
            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
            ),
          ),
        ),

        // ── Results dropdown ──────────────────────
        if (results.isNotEmpty && _hasFocus)
          Material(
            elevation: 6,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: results.length > 5 ? 5 : results.length,
              separatorBuilder: (context, index) => const Divider(height: 1, indent: 16),
              itemBuilder: (context, index) {
                final r = results[index];
                // First part is the main name, rest is address context
                final parts = r.displayName.split(',');
                final mainName = parts.first.trim();
                final context2 = parts.length > 1 ? parts.skip(1).take(2).join(',').trim() : '';

                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.place_outlined, size: 18),
                  title: Text(mainName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  subtitle: context2.isNotEmpty
                      ? Text(context2, style: const TextStyle(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis)
                      : null,
                  onTap: () => selectResult(r),
                );
              },
            ),
          ),
      ],
    );
  }
}