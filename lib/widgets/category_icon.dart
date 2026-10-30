import 'package:flutter/material.dart';

// Category IDs differ between editions; names are shared by Home and Explore.
IconData categoryIcon(String name) {
  final normalized = name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  return switch (normalized) {
    'hot products' => Icons.new_releases_rounded,
    'woodworking news' => Icons.handyman_rounded,
    'featured news' || 'featured news spl' => Icons.stars_rounded,
    'latest wood news' || 'latest news' => Icons.newspaper_rounded,
    'woodword' => Icons.forum_rounded,
    'united states of america' ||
    'united states' ||
    'usa' =>
      Icons.flag_rounded,
    'canada' => Icons.forest_rounded,
    'mexico' => Icons.location_city_rounded,
    'latin america' => Icons.public_rounded,
    'north america' => Icons.explore_rounded,
    'woodworking events' || 'events' => Icons.event_available_rounded,
    'appointments and acquisitions' ||
    'appointments' ||
    'appoints' =>
      Icons.business_center_rounded,
    'sustainability' => Icons.eco_rounded,
    'furniture fittings' => Icons.chair_rounded,
    'adhesives and coatings' => Icons.format_paint_rounded,
    'decor' => Icons.palette_rounded,
    'woodworking software' => Icons.computer_rounded,
    'forestry technology' => Icons.forest_rounded,
    'surface finishing' => Icons.layers_rounded,
    'flooring' => Icons.grid_on_rounded,
    'tools for wood processing' => Icons.construction_rounded,
    'woodworking machinery' => Icons.precision_manufacturing_rounded,
    'interview' || 'interviews' => Icons.record_voice_over_rounded,
    'video' || 'videos' || 'video home' => Icons.play_circle_rounded,
    'gallery' => Icons.photo_library_rounded,
    'press release' => Icons.campaign_rounded,
    'trending' => Icons.trending_up_rounded,
    'phone app features' => Icons.phone_android_rounded,
    _ => Icons.article_rounded,
  };
}
