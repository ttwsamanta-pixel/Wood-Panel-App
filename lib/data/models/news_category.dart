class NewsCategory {
  const NewsCategory({
    required this.id,
    required this.name,
  });

  final int id;
  final String name;

  static NewsCategory byId(int id) {
    return all.firstWhere(
      (category) => category.id == id,
      orElse: () => all.first,
    );
  }

  static const all = <NewsCategory>[
    NewsCategory(id: 30036, name: 'Hot Products'),
    NewsCategory(id: 27527, name: 'Woodworking News'),
    NewsCategory(id: 31124, name: 'Woodworking Events'),
    NewsCategory(id: 33793, name: 'Appointments and Acquisitions'),
    NewsCategory(id: 33794, name: 'Sustainability'),
    NewsCategory(id: 33795, name: 'Furniture Fittings'),
    NewsCategory(id: 31111, name: 'Adhesives and Coatings'),
    NewsCategory(id: 33796, name: 'Decor'),
    NewsCategory(id: 31112, name: 'Woodworking Software'),
    NewsCategory(id: 31118, name: 'Forestry Technology'),
    NewsCategory(id: 33797, name: 'Surface Finishing'),
    NewsCategory(id: 33798, name: 'Flooring'),
    NewsCategory(id: 31115, name: 'Tools for Wood Processing'),
    NewsCategory(id: 33799, name: 'Woodworking Machinery'),
  ];
}
