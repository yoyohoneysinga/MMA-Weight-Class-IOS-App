import SwiftUI

// MARK: - Models

enum CategoryType: String, CaseIterable, Hashable {
    case striking = "Striking"
    case grappling = "Grappling"
    case fitness = "Fitness"
    
    var icon: String {
        switch self {
        case .striking: return "hand.raised.fill"
        case .grappling: return "figure.wrestling"
        case .fitness: return "figure.run"
        }
    }
    
    var color: Color {
        switch self {
        case .striking: return .red
        case .grappling: return .blue
        case .fitness: return .green
        }
    }
}

class SubMove: Identifiable, ObservableObject {
    let id = UUID()
    @Published var name: String
    @Published var stars: Double

    init(name: String, stars: Double = 0) {
        self.name = name
        self.stars = stars
    }

    weak var move: Move? // Add this
    
    func updateStore() {
        move?.updateStore()
    }
}

class Move: Identifiable, ObservableObject {
    let id = UUID()
    @Published var name: String
    @Published var subMoves: [SubMove] = []
    @Published var stars: Double = 0

    init(name: String, stars: Double = 0, subMoves: [SubMove] = []) {
        self.name = name
        self.stars = stars
        self.subMoves = subMoves
        self.subMoves.forEach { $0.move = self }
    }

    var averageStars: Double {
        if subMoves.isEmpty {
            return stars
        } else {
            let total = subMoves.reduce(0) { $0 + $1.stars }
            return total / Double(subMoves.count)
        }
    }

    weak var subcategory: Subcategory? // Add this
    
    func updateStore() {
        objectWillChange.send()
        subcategory?.updateStore()
    }
}

class Subcategory: Identifiable, ObservableObject {
    let id = UUID()
    @Published var name: String
    @Published var moves: [Move] = []
    @Published var stars: Double = 0

    init(name: String, stars: Double = 0, moves: [Move] = []) {
        self.name = name
        self.stars = stars
        self.moves = moves
        self.moves.forEach { $0.subcategory = self }
    }

    var averageStars: Double {
        if moves.isEmpty {
            return stars
        } else {
            let total = moves.reduce(0) { $0 + $1.averageStars }
            return total / Double(moves.count)
        }
    }

    weak var discipline: Discipline?
    
    func updateStore() {
        objectWillChange.send()
        discipline?.updateStore()
    }
}

class Discipline: Identifiable, ObservableObject {
    let id = UUID()
    @Published var name: String
    @Published var category: CategoryType
    @Published var subcategories: [Subcategory] = []
    @Published var stars: Double = 0

    init(name: String, category: CategoryType = .striking, stars: Double = 0, subcategories: [Subcategory] = []) {
        self.name = name
        self.category = category
        self.stars = stars
        self.subcategories = subcategories
        self.subcategories.forEach { $0.discipline = self }
    }

    var averageStars: Double {
        if subcategories.isEmpty {
            return stars
        } else {
            let total = subcategories.reduce(0) { $0 + $1.averageStars }
            return total / Double(subcategories.count)
        }
    }

    weak var store: DataStore?
    
    func updateStore() {
        objectWillChange.send()
        store?.forceUpdate()
    }
}

class DataStore: ObservableObject {
    @Published var disciplines: [Discipline] = [] {
        didSet {
            // Ensure proper parent-child relationships
            disciplines.forEach { discipline in
                discipline.store = self
                discipline.subcategories.forEach { subcategory in
                    subcategory.discipline = discipline
                    subcategory.moves.forEach { move in
                        move.subcategory = subcategory
                        move.subMoves.forEach { subMove in
                            subMove.move = move
                        }
                    }
                }
            }
        }
    }
    
    func disciplinesForCategory(_ category: CategoryType?) -> [Discipline] {
        guard let category = category else {
            return disciplines
        }
        return disciplines.filter { $0.category == category }
    }
    
    func averageStarsForDiscipline(_ discipline: Discipline) -> Double {
        let subcategories = discipline.subcategories
        guard !subcategories.isEmpty else { return discipline.stars }
        return subcategories.reduce(0.0) { $0 + $1.averageStars } / Double(subcategories.count)
    }
    
    func averageStarsForCategory(_ category: CategoryType) -> Double {
        let categoryDisciplines = disciplinesForCategory(category)
        guard !categoryDisciplines.isEmpty else { return 0 }
        return categoryDisciplines.reduce(0.0) { $0 + averageStarsForDiscipline($1) } / Double(categoryDisciplines.count)
    }
    
    // Add this method to force UI updates
    func forceUpdate() {
        objectWillChange.send()
        // Force update all disciplines
        disciplines.forEach { discipline in
            discipline.objectWillChange.send()
            discipline.subcategories.forEach { subcategory in
                subcategory.objectWillChange.send()
                subcategory.moves.forEach { move in
                    move.objectWillChange.send()
                    move.subMoves.forEach { subMove in
                        subMove.objectWillChange.send()
                    }
                }
            }
        }
    }
}

// MARK: - Custom Components

struct StarView: View {
    let stars: Double
    let maxStars: Int = 5
    let size: CGFloat
    let interactive: Bool
    let onRatingChanged: ((Double) -> Void)?

    init(stars: Double, size: CGFloat = 14, interactive: Bool = false, onRatingChanged: ((Double) -> Void)? = nil) {
        self.stars = stars
        self.size = size
        self.interactive = interactive
        self.onRatingChanged = onRatingChanged
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...maxStars, id: \.self) { i in
                let filled = Double(i) <= stars
                let halfFilled = Double(i) - 0.5 <= stars && stars < Double(i)
                
                Button(action: {
                    if interactive {
                        let newRating = Double(i)
                        onRatingChanged?(newRating)
                    }
                }) {
                    Image(systemName: filled ? "star.fill" : (halfFilled ? "star.leadinghalf.filled" : "star"))
                        .foregroundColor(getStarColor(for: stars))
                        .font(.system(size: size))
                }
                .disabled(!interactive)
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    private func getStarColor(for rating: Double) -> Color {
        if rating >= 4.5 { return .yellow }
        else if rating >= 3.5 { return .orange }
        else if rating >= 2.5 { return .blue }
        else if rating >= 1.5 { return .green }
        else { return .gray }
    }
}

struct ModernCard<Content: View>: View {
    let content: Content
    let backgroundColor: Color
    
    init(backgroundColor: Color = Color(.systemBackground), @ViewBuilder content: () -> Content) {
        self.content = content()
        self.backgroundColor = backgroundColor
    }
    
    var body: some View {
        content
            .padding(20)
            .background(backgroundColor)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(.systemGray5), lineWidth: 1)
            )
    }
}

struct EditableTextField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    @State private var isEditing = false
    
    var body: some View {
        HStack {
            if isEditing {
                TextField(placeholder, text: $text)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.headline)
                    .onSubmit {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isEditing = false
                        }
                    }
            } else {
                Text(text.isEmpty ? placeholder : text)
                    .font(.headline)
                    .foregroundColor(text.isEmpty ? .secondary : .primary)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isEditing = true
                        }
                    }
            }
            
            Spacer()
            
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isEditing.toggle()
                }
            }) {
                Image(systemName: isEditing ? "checkmark.circle.fill" : "pencil.circle.fill")
                    .foregroundColor(isEditing ? .green : .blue)
                    .font(.title3)
            }
        }
    }
}

struct CategoryPicker: View {
    @Binding var selectedCategory: CategoryType
    @State private var isEditing = false
    
    var body: some View {
        HStack {
            if isEditing {
                Picker("Category", selection: $selectedCategory) {
                    ForEach(CategoryType.allCases, id: \.self) { category in
                        HStack {
                            Image(systemName: category.icon)
                            Text(category.rawValue)
                        }
                        .tag(category)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .onChange(of: selectedCategory) { oldValue, newValue in
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isEditing = false
                    }
                }
            } else {
                HStack {
                    Image(systemName: selectedCategory.icon)
                        .foregroundColor(selectedCategory.color)
                    Text(selectedCategory.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(selectedCategory.color.opacity(0.1))
                .cornerRadius(8)
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isEditing = true
                    }
                }
            }
            
            Spacer()
            
            if !isEditing {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isEditing = true
                    }
                }) {
                    Image(systemName: "pencil.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                }
            }
        }
    }
}

struct RatingRow: View {
    let title: String
    let stars: Double
    let showNumeric: Bool
    let isEditable: Bool
    let onRatingChanged: ((Double) -> Void)?
    
    init(title: String, stars: Double, showNumeric: Bool = true, isEditable: Bool = false, onRatingChanged: ((Double) -> Void)? = nil) {
        self.title = title
        self.stars = stars
        self.showNumeric = showNumeric
        self.isEditable = isEditable
        self.onRatingChanged = onRatingChanged
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HStack(spacing: 8) {
                    StarView(stars: stars, size: 16, interactive: isEditable, onRatingChanged: { newRating in
                        onRatingChanged?(newRating)
                    })
                    if showNumeric {
                        Text("\(stars, specifier: "%.1f")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                }
            }
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Views

struct DisciplineListView: View {
    @ObservedObject var store: DataStore
    @State private var showingAddDiscipline = false
    @State private var searchText = ""
    @State private var selectedCategory: CategoryType?

    var filteredDisciplines: [Discipline] {
        let disciplines = selectedCategory.map { store.disciplinesForCategory($0) } ?? store.disciplines
        if searchText.isEmpty {
            return disciplines
        }
        return disciplines.filter { discipline in
            discipline.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var categories: [(String, CategoryType?)] {
        [("All", nil)] + CategoryType.allCases.map { ($0.rawValue, $0) }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Category filter
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(categories, id: \.0) { name, category in
                                Button(action: {
                                    withAnimation {
                                        selectedCategory = category
                                    }
                                }) {
                                    HStack {
                                        if let category = category {
                                            Image(systemName: category.icon)
                                                .foregroundColor(selectedCategory == category ? .white : category.color)
                                        } else {
                                            Image(systemName: "line.3.horizontal.decrease.circle")
                                                .foregroundColor(selectedCategory == nil ? .white : .gray)
                                        }
                                        Text(name)
                                            .foregroundColor(selectedCategory == category ? .white : .primary)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(category.map { selectedCategory == category ? $0.color : $0.color.opacity(0.1) } ?? 
                                                (selectedCategory == nil ? Color.blue : Color(.systemGray6)))
                                    )
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    LazyVStack(spacing: 16) {
                        ForEach(filteredDisciplines) { discipline in
                            NavigationLink(destination: DisciplineDetailView(discipline: discipline)) {
                                ModernCard {
                                    VStack(alignment: .leading, spacing: 16) {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 8) {
                                                Text(discipline.name)
                                                    .font(.title2)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(.primary)
                                                
                                                HStack {
                                                    Image(systemName: discipline.category.icon)
                                                        .foregroundColor(discipline.category.color)
                                                    Text(discipline.category.rawValue)
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(discipline.category.color.opacity(0.1))
                                                .cornerRadius(8)
                                            }
                                            
                                            Spacer()
                                            
                                            VStack(alignment: .trailing, spacing: 8) {
                                                StarView(stars: discipline.averageStars, size: 20)
                                                Text("\(discipline.averageStars, specifier: "%.1f")")
                                                    .font(.title2)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(.primary)
                                            }
                                        }
                                        
                                        if !discipline.subcategories.isEmpty {
                                            Divider()
                                            HStack {
                                                Image(systemName: "list.bullet")
                                                    .foregroundColor(.secondary)
                                                Text("\(discipline.subcategories.count) subcategories")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding()
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Disciplines")
            .searchable(text: $searchText, prompt: "Search disciplines...")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddDiscipline = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                }
            }
            .sheet(isPresented: $showingAddDiscipline) {
                AddDisciplineView(store: store, isPresented: $showingAddDiscipline)
            }
        }
    }
}

struct AddDisciplineView: View {
    @ObservedObject var store: DataStore
    @Binding var isPresented: Bool
    @State private var name = ""
    @State private var selectedCategory: CategoryType = .striking

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Discipline Details")) {
                    TextField("Discipline Name", text: $name)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Category")
                            .font(.headline)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            ForEach(CategoryType.allCases, id: \.self) { category in
                                Button(action: {
                                    selectedCategory = category
                                }) {
                                    VStack(spacing: 8) {
                                        Image(systemName: category.icon)
                                            .font(.title2)
                                            .foregroundColor(selectedCategory == category ? .white : category.color)
                                        
                                        Text(category.rawValue)
                                            .font(.caption)
                                            .foregroundColor(selectedCategory == category ? .white : .primary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(16)
                                    .background(selectedCategory == category ? category.color : Color(.systemGray6))
                                    .cornerRadius(12)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Add Discipline")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let newDiscipline = Discipline(name: name, category: selectedCategory)
                        newDiscipline.store = store  // Add this line
                        store.disciplines.append(newDiscipline)
                        store.forceUpdate()  // Add this line
                        isPresented = false
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
            }
        }
    }
}

struct DisciplineDetailView: View {
    @ObservedObject var discipline: Discipline
    @State private var showingAddSubcategory = false
    @State private var showingDeleteAlert = false
    @State private var subcategoryToDelete: Subcategory?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // Header Card
                ModernCard(backgroundColor: discipline.category.color.opacity(0.05)) {
                    VStack(alignment: .leading, spacing: 16) {
                        EditableTextField(title: "Name", text: Binding(
                            get: { discipline.name },
                            set: { newValue in
                                discipline.name = newValue
                                discipline.updateStore()
                            }
                        ), placeholder: "Discipline Name")
                        
                        CategoryPicker(selectedCategory: Binding(
                            get: { discipline.category },
                            set: { newValue in
                                discipline.category = newValue
                                discipline.updateStore()
                            }
                        ))
                        
                        Divider()
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Overall Rating")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                HStack(spacing: 8) {
                                    StarView(stars: discipline.averageStars, size: 24)
                                    Text("\(discipline.averageStars, specifier: "%.1f")")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                }
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Subcategories")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(discipline.subcategories.count)")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                }
                
                // Subcategories
                ForEach(discipline.subcategories) { subcategory in
                    NavigationLink(destination: SubcategoryDetailView(subcategory: subcategory)) {
                        ModernCard {
                            HStack {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(subcategory.name)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    HStack(spacing: 8) {
                                        StarView(stars: subcategory.averageStars, size: 16)
                                        Text("\(subcategory.averageStars, specifier: "%.1f")")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        Spacer()
                                        
                                        if !subcategory.moves.isEmpty {
                                            HStack {
                                                Image(systemName: "list.bullet")
                                                    .foregroundColor(.secondary)
                                                Text("\(subcategory.moves.count) moves")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .contextMenu {
                        Button(role: .destructive) {
                            subcategoryToDelete = subcategory
                            showingDeleteAlert = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(discipline.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAddSubcategory = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
        }
        .sheet(isPresented: $showingAddSubcategory) {
            AddSubcategoryView(discipline: discipline, isPresented: $showingAddSubcategory)
        }
        .alert("Delete Subcategory", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                if let subcategory = subcategoryToDelete {
                    discipline.subcategories.removeAll { $0.id == subcategory.id }
                    discipline.updateStore()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this subcategory? This action cannot be undone.")
        }
    }
}

struct AddSubcategoryView: View {
    @ObservedObject var discipline: Discipline
    @Binding var isPresented: Bool
    @State private var name = ""
    @State private var stars: Double = 0
    @State private var hasMoves = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Subcategory Details")) {
                    TextField("Subcategory Name", text: $name)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Toggle("Will contain moves", isOn: $hasMoves.animation())
                    
                    if !hasMoves {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Initial Rating")
                                .font(.headline)
                            
                            HStack(spacing: 12) {
                                StarView(stars: stars, size: 20)
                                Text("\(stars, specifier: "%.1f")")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                            }
                            
                            Slider(value: $stars, in: 0...5, step: 0.5)
                                .accentColor(discipline.category.color)
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("Add Subcategory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let newSubcategory = Subcategory(name: name, stars: hasMoves ? 0 : stars)
                        newSubcategory.discipline = discipline  // Add this line
                        discipline.subcategories.append(newSubcategory)
                        discipline.updateStore()  // Add this line
                        isPresented = false
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
            }
        }
    }
}

struct SubcategoryDetailView: View {
    @ObservedObject var subcategory: Subcategory
    @State private var showingAddMove = false
    @State private var showingDeleteAlert = false
    @State private var moveToDelete: Move?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Header Card
                ModernCard(backgroundColor: Color(.systemGray6).opacity(0.3)) {
                    VStack(alignment: .leading, spacing: 16) {
                        EditableTextField(title: "Name", text: $subcategory.name, placeholder: "Subcategory Name")
                        
                        if subcategory.moves.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Rating")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                HStack(spacing: 12) {
                                    StarView(stars: subcategory.stars, size: 24, interactive: true) { newRating in
                                        subcategory.stars = newRating
                                        subcategory.updateStore()
                                    }
                                    Text("\(subcategory.stars, specifier: "%.1f")")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                }
                                
                                Slider(value: Binding(
                                    get: { subcategory.stars },
                                    set: { newValue in
                                        subcategory.stars = newValue
                                        subcategory.updateStore()
                                    }
                                ), in: 0...5, step: 0.5)
                                .accentColor(.blue)
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Average Rating")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                HStack(spacing: 12) {
                                    StarView(stars: subcategory.averageStars, size: 24)
                                    Text("\(subcategory.averageStars, specifier: "%.1f")")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                    
                                    Spacer()
                                    
                                    Text("\(subcategory.moves.count) moves")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                
                // Moves
                ForEach(subcategory.moves) { move in
                    NavigationLink(destination: MoveDetailView(move: move)) {
                        ModernCard {
                            HStack {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(move.name)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    HStack(spacing: 8) {
                                        StarView(stars: move.averageStars, size: 16)
                                        Text("\(move.averageStars, specifier: "%.1f")")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        Spacer()
                                        
                                        if !move.subMoves.isEmpty {
                                            HStack {
                                                Image(systemName: "list.bullet")
                                                    .foregroundColor(.secondary)
                                                Text("\(move.subMoves.count) sub-actions")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .contextMenu {
                        Button(role: .destructive) {
                            moveToDelete = move
                            showingDeleteAlert = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(subcategory.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAddMove = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
        }
        .sheet(isPresented: $showingAddMove) {
            AddMoveView(subcategory: subcategory, isPresented: $showingAddMove)
        }
        .alert("Delete Move", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                if let move = moveToDelete {                            subcategory.moves.removeAll { $0.id == move.id }
                            subcategory.updateStore()
                        }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this move? This action cannot be undone.")
        }
    }
}

struct AddMoveView: View {
    @ObservedObject var subcategory: Subcategory
    @Binding var isPresented: Bool
    @State private var name = ""
    @State private var stars: Double = 0
    @State private var hasSubMoves = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Move Details")) {
                    TextField("Move Name", text: $name)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Toggle("Will contain sub-actions", isOn: $hasSubMoves.animation())
                    
                    if !hasSubMoves {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Initial Rating")
                                .font(.headline)
                            
                            HStack(spacing: 12) {
                                StarView(stars: stars, size: 20)
                                Text("\(stars, specifier: "%.1f")")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                            }
                            
                            Slider(value: $stars, in: 0...5, step: 0.5)
                                .accentColor(.blue)
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("Add Move")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let newMove = Move(name: name, stars: hasSubMoves ? 0 : stars)
                        newMove.subcategory = subcategory  // Add this line
                        subcategory.moves.append(newMove)
                        subcategory.updateStore()  // Add this line
                        isPresented = false
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
            }
        }
    }
}

struct MoveDetailView: View {
    @ObservedObject var move: Move
    @State private var showingAddSubMove = false
    @State private var showingDeleteAlert = false
    @State private var subMoveToDelete: SubMove?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Header Card
                ModernCard(backgroundColor: Color(.systemGray6).opacity(0.3)) {
                    VStack(alignment: .leading, spacing: 16) {
                        EditableTextField(title: "Name", text: $move.name, placeholder: "Move Name")
                        
                        if move.subMoves.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Rating")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                HStack(spacing: 12) {
                                    StarView(stars: move.stars, size: 24, interactive: true) { newRating in
                                        move.stars = newRating
                                        move.updateStore()
                                    }
                                    Text("\(move.stars, specifier: "%.1f")")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                }
                                
                                Slider(value: Binding(
                                    get: { move.stars },
                                    set: { newValue in
                                        move.stars = newValue
                                        move.updateStore()
                                    }
                                ), in: 0...5, step: 0.5)
                                .accentColor(.blue)
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Average Rating")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                HStack(spacing: 12) {
                                    StarView(stars: move.averageStars, size: 24)
                                    Text("\(move.averageStars, specifier: "%.1f")")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                    
                                    Spacer()
                                    
                                    Text("\(move.subMoves.count) sub-actions")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                
                // Sub-moves
                ForEach(move.subMoves) { subMove in
                    ModernCard {
                        SubMoveRow(subMove: subMove)
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            subMoveToDelete = subMove
                            showingDeleteAlert = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(move.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAddSubMove = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
        }
        .sheet(isPresented: $showingAddSubMove) {
            AddSubMoveView(move: move, isPresented: $showingAddSubMove)
        }
        .alert("Delete Sub-action", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                if let subMove = subMoveToDelete {                            move.subMoves.removeAll { $0.id == subMove.id }
                            move.updateStore()
                        }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this sub-action? This action cannot be undone.")
        }
    }
}

struct SubMoveRow: View {
    @ObservedObject var subMove: SubMove
    @State private var isEditingName = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Editable name
            HStack {
                if isEditingName {
                    TextField("Sub-action Name", text: $subMove.name)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onSubmit {
                            isEditingName = false
                            subMove.updateStore()
                        }
                } else {
                    Text(subMove.name)
                        .onTapGesture {
                            isEditingName = true
                        }
                }
                
                Spacer()
                
                Button(action: {
                    isEditingName.toggle()
                }) {
                    Image(systemName: isEditingName ? "checkmark.circle.fill" : "pencil.circle.fill")
                        .foregroundColor(isEditingName ? .green : .blue)
                }
            }
            
            // Rating section
            VStack(alignment: .leading, spacing: 8) {
                StarView(stars: subMove.stars, size: 16, interactive: true) { newRating in
                    subMove.stars = newRating
                    subMove.updateStore()
                }
                
                HStack {
                    Text("\(subMove.stars, specifier: "%.1f")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

struct AddSubMoveView: View {
    @ObservedObject var move: Move
    @Binding var isPresented: Bool
    @State private var name = ""
    @State private var stars: Double = 0

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Sub-action Details")) {
                    TextField("Sub-action Name", text: $name)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Initial Rating")
                            .font(.headline)
                        
                        HStack(spacing: 12) {
                            StarView(stars: stars, size: 20)
                            Text("\(stars, specifier: "%.1f")")
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                        
                        Slider(value: $stars, in: 0...5, step: 0.5)
                            .accentColor(.blue)
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Add Sub-action")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let newSubMove = SubMove(name: name, stars: stars)
                        newSubMove.move = move  // Add this line
                        move.subMoves.append(newSubMove)
                        move.updateStore()  // Add this line
                        isPresented = false
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
            }
        }
    }
}

// MARK: - CategoryView

struct CategoryView: View {
    @ObservedObject var store: DataStore
    @State private var selectedCategory: CategoryType?
    @State private var searchText = ""
    
    var filteredDisciplines: [Discipline] {
        let disciplines = selectedCategory.map { store.disciplinesForCategory($0) } ?? store.disciplines
        if searchText.isEmpty {
            return disciplines
        }
        return disciplines.filter { discipline in
            discipline.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var categories: [(String, CategoryType?)] {
        [("All", nil)] + CategoryType.allCases.map { ($0.rawValue, $0) }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Category filter
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(categories, id: \.0) { name, category in
                                Button(action: {
                                    withAnimation {
                                        selectedCategory = category
                                    }
                                }) {
                                    HStack {
                                        if let category = category {
                                            Image(systemName: category.icon)
                                                .foregroundColor(selectedCategory == category ? .white : category.color)
                                        } else {
                                            Image(systemName: "line.3.horizontal.decrease.circle")
                                                .foregroundColor(selectedCategory == nil ? .white : .gray)
                                        }
                                        Text(name)
                                            .foregroundColor(selectedCategory == category ? .white : .primary)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(category.map { selectedCategory == category ? $0.color : $0.color.opacity(0.1) } ?? 
                                                (selectedCategory == nil ? Color.blue : Color(.systemGray6)))
                                    )
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    LazyVStack(spacing: 16) {
                        ForEach(filteredDisciplines) { discipline in
                            NavigationLink(destination: DisciplineDetailView(discipline: discipline)) {
                                ModernCard {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text(discipline.name)
                                                .font(.title2)
                                                .fontWeight(.bold)
                                                .foregroundColor(.primary)
                                            
                                            HStack {
                                                Image(systemName: discipline.category.icon)
                                                    .foregroundColor(discipline.category.color)
                                                Text(discipline.category.rawValue)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(discipline.category.color.opacity(0.1))
                                            .cornerRadius(8)
                                        }
                                        
                                        Spacer()
                                        
                                        VStack(alignment: .trailing) {
                                            Text("\(discipline.subcategories.count)")
                                                .font(.title2)
                                                .fontWeight(.bold)
                                                .foregroundColor(.primary)
                                            Text(discipline.subcategories.count == 1 ? "subcategory" : "subcategories")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding()
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Categories")
            .searchable(text: $searchText, prompt: "Search disciplines...")
        }
    }
}

// MARK: - Root View

struct ContentView: View {
    @StateObject var store = DataStore()

    var body: some View {
        DisciplineListView(store: store)
            .accentColor(.blue)
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
