import '../models/models.dart';

// Nội dung lấy từ Lab 2: assets/stitch/F03-knowledge và F03-planning.
// Món và bài của Longevity Plate là minh họa, không phải chỉ định y tế.
const bowlImage = 'assets/images/bowl.png';
const toastImage = 'assets/images/toast.png';
const mealPrepImage = 'assets/images/meal_prep.png';

const recipesData = <Recipe>[
  Recipe(
    id: 'rice-veg-beans',
    title: 'Cơm rau củ và đậu',
    summary: 'Cơm gạo lứt dùng cùng rau củ, đậu hũ và đậu nành lông.',
    image: bowlImage,
    ingredients: [
      'Cơm gạo lứt',
      'Đậu hũ và đậu nành lông',
      'Rau cải, cà rốt',
      'Dầu ô liu, mè và gia vị',
    ],
    steps: [
      'Nấu gạo lứt chín mềm.',
      'Sơ chế rau, hấp hoặc luộc vừa chín; làm nóng đậu hũ và đậu.',
      'Xếp vào bát, thêm dầu ô liu, mè và gia vị vừa ăn.',
    ],
  ),
  Recipe(
    id: 'toast-egg',
    title: 'Bánh mì và trứng',
    summary: 'Bánh mì nướng, trứng ốp và một ít rau xanh.',
    image: toastImage,
    ingredients: ['Bánh mì', 'Trứng', 'Rau xanh', 'Gia vị vừa ăn'],
    steps: [
      'Nướng bánh mì đến khi vàng nhẹ.',
      'Ốp trứng theo độ chín bạn thích.',
      'Xếp trứng lên bánh, thêm rau xanh và gia vị.',
    ],
  ),
  Recipe(
    id: 'meal-prep-box',
    title: 'Hộp cơm chuẩn bị sẵn',
    summary: 'Chia cơm, rau và đậu vào hộp cho bữa sắp tới.',
    image: mealPrepImage,
    ingredients: ['Cơm', 'Rau luộc', 'Đậu hoặc đậu hũ', 'Hộp đựng có nắp'],
    steps: [
      'Nấu sẵn cơm và sơ chế rau.',
      'Chia từng phần vào hộp đựng.',
      'Bảo quản lạnh và hâm nóng trước khi dùng.',
    ],
  ),
];

const articlesData = <Article>[
  Article(
    id: 'who-diverse',
    title: 'Bữa ăn đa dạng bắt đầu từ đâu?',
    source: 'Tham khảo: WHO · Healthy diet',
    sourceDate: '26/01/2026',
    note: 'Nội dung được diễn giải bởi Longevity Plate.',
    image: bowlImage,
    sourceUrl: 'https://www.who.int/news-room/fact-sheets/detail/healthy-diet',
    sourceLinkLabel: 'Xem nguồn WHO',
    sections: [
      ArticleSection(
        'Đa dạng từ những lựa chọn quen thuộc',
        'Một bữa ăn có thể kết hợp thực phẩm từ nhiều nhóm khác nhau, tùy thói quen và điều kiện của bạn.',
      ),
      ArticleSection(
        'Thêm lựa chọn từ thực vật',
        'Rau củ, trái cây, ngũ cốc nguyên hạt và các loại đậu là những nhóm thực phẩm được đề cập trong hướng dẫn của WHO.',
      ),
      ArticleSection(
        'Chủ động từ một bữa ăn',
        'Bạn có thể chọn một bữa sắp tới, xem nguyên liệu sẵn có và lên kế hoạch phù hợp với thời gian của mình.',
      ),
    ],
  ),
  Article(
    id: 'harvard-plate',
    title: 'Gợi ý xây dựng đĩa ăn cân bằng',
    source: 'Harvard T.H. Chan · Healthy Eating Plate',
    image: toastImage,
    sourceUrl: 'https://nutritionsource.hsph.harvard.edu/healthy-eating-plate/',
    sourceLinkLabel: 'Xem nguồn Harvard',
    externalOnly: true,
  ),
  Article(
    id: 'busy-prep',
    title: 'Chuẩn bị bữa ăn cho ngày bận rộn',
    source: 'Longevity Plate · Nội dung minh họa',
    summary: 'Sắp xếp nguyên liệu cho một bữa sắp tới.',
    note: 'Nội dung minh họa của Longevity Plate.',
    image: mealPrepImage,
    sections: [
      ArticleSection(
        'Chọn trước một bữa',
        'Bắt đầu từ một bữa bạn hay bận nhất, thay vì lên kế hoạch cho cả tuần ngay từ đầu.',
      ),
      ArticleSection(
        'Sắp xếp nguyên liệu',
        'Xem những gì đang có trong bếp và để sẵn các nguyên liệu dùng chung cho bữa đó.',
      ),
      ArticleSection(
        'Điều chỉnh theo nhịp sống',
        'Nếu lịch thay đổi, bạn có thể đổi món trong kế hoạch tuần mà không cần bắt đầu lại.',
      ),
    ],
  ),
];
