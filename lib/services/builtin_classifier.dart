import 'ocr_result.dart';

class BuiltinClassifier {
  /// Each subject has: keywords (weight 1), strongKeywords (weight 3),
  /// patterns (weight 5), antiKeywords (negative weight -2)
  static const Map<String, Map<String, List<String>>> _subjects = {
    // ── MATHEMATICS ─────────────────────────────────────────────
    'mathematics': {
      'keywords': [
        'number', 'equation', 'solve', 'calculate', 'formula',
        'graph', 'plot', 'axis', 'coordinate', 'plane',
        'polynomial', 'coefficient', 'variable', 'expression',
        'factor', 'prime', 'divisible', 'rational', 'irrational',
        'real', 'imaginary', 'complex', 'set', 'subset',
        'union', 'intersection', 'function', 'domain', 'range',
        'sequence', 'series', 'convergence', 'divergence',
        'permutation', 'combination', 'binomial', 'theorem',
        'proof', 'induction', 'axiom', 'postulate', 'lemma',
      ],
      'strongKeywords': [
        'calculus', 'algebra', 'geometry', 'trigonometry',
        'statistics', 'probability', 'arithmetic', 'logarithm',
        'derivative', 'integral', 'differential', 'matrix',
        'vector', 'determinant', 'eigenvalue', 'quadratic',
        'linear', 'polynomial', 'fraction', 'percentage',
        'pythagorean', 'theorem', 'inequality', 'modulus',
        'sine', 'cosine', 'tangent', 'radian', 'degree',
        'parabola', 'hyperbola', 'ellipse', 'asymptote',
      ],
      'patterns': [
        'calculus', 'derivative', 'integral', 'summation',
        'limit', 'trigonometry', 'matrix algebra',
        'quadratic algebra', 'logarithm mathematics',
        'function mathematics', 'geometry theorem',
        'polynomial algebra', 'probability statistics',
      ],
      'antiKeywords': [
        'atom', 'cell', 'war', 'poem', 'evolution', 'circuit',
      ],
    },

    // ── PHYSICS ─────────────────────────────────────────────────
    'physics': {
      'keywords': [
        'motion', 'speed', 'distance', 'displacement', 'time',
        'mass', 'weight', 'gravity', 'force', 'pressure',
        'density', 'volume', 'temperature', 'heat', 'work',
        'power', 'energy', 'charge', 'field', 'flux',
        'wave', 'light', 'sound', 'optics', 'lens',
        'reflection', 'refraction', 'diffraction', 'interference',
        'nuclear', 'radioactive', 'decay', 'fission', 'fusion',
        'momentum', 'impulse', 'torque', 'friction', 'tension',
      ],
      'strongKeywords': [
        'velocity', 'acceleration', 'newton', 'kinematics',
        'dynamics', 'thermodynamics', 'electromagnetism',
        'quantum', 'relativity', 'mechanics', 'electricity',
        'magnetism', 'electromagnetic', 'photon', 'electron',
        'proton', 'neutron', 'nucleus', 'atom', 'orbital',
        'resistance', 'voltage', 'current', 'circuit',
        'capacitor', 'inductor', 'transformer', 'semiconductor',
      ],
      'patterns': [
        'force newton physics', 'kinematics motion',
        'electricity circuit', 'waves frequency physics',
        'gravity physics', 'energy physics',
        'thermodynamics physics', 'quantum physics',
        'relativity physics',
      ],
      'antiKeywords': [
        'cell', 'dna', 'poem', 'novel', 'war', 'supply', 'demand',
      ],
    },

    // ── CHEMISTRY ───────────────────────────────────────────────
    'chemistry': {
      'keywords': [
        'element', 'compound', 'mixture', 'solution', 'solvent',
        'solute', 'concentration', 'dilution', 'titration',
        'precipitate', 'filtration', 'distillation', 'separation',
        'atom', 'ion', 'proton', 'neutron', 'electron',
        'orbital', 'valence', 'shell', 'nucleus', 'isotope',
        'metal', 'nonmetal', 'metalloid', 'noble', 'gas',
        'organic', 'inorganic', 'polymer', 'monomer', 'catalyst',
        'inhibitor', 'equilibrium', 'exothermic', 'endothermic',
      ],
      'strongKeywords': [
        'molecule', 'reaction', 'acid', 'base', 'ph',
        'oxidation', 'reduction', 'bond', 'ionic', 'covalent',
        'periodic', 'mole', 'enzyme', 'carbon', 'hydrogen',
        'oxygen', 'nitrogen', 'formula', 'balanced', 'redox',
        'enthalpy', 'entropy', 'gibbs', 'buffer', 'electrolyte',
        'hydrolysis', 'polymerization', 'alkane', 'alkene',
        'benzene', 'functional', 'group', 'isomer',
      ],
      'patterns': [
        'chemical formula chemistry', 'chemical reaction',
        'mole chemistry', 'acid base chemistry',
        'redox chemistry', 'chemical bond',
        'periodic table chemistry', 'thermochemistry',
      ],
      'antiKeywords': [
        'war', 'poem', 'novel', 'force', 'velocity', 'grammar',
      ],
    },

    // ── BIOLOGY ─────────────────────────────────────────────────
    'biology': {
      'keywords': [
        'organism', 'species', 'habitat', 'ecosystem', 'biome',
        'population', 'community', 'food', 'chain', 'web',
        'predator', 'prey', 'symbiosis', 'parasite', 'host',
        'reproduction', 'sexual', 'asexual', 'spore', 'seed',
        'germination', 'growth', 'development', 'aging', 'death',
        'homeostasis', 'stimulus', 'response', 'receptor',
        'blood', 'heart', 'lung', 'liver', 'kidney', 'brain',
        'muscle', 'bone', 'skin', 'nerve', 'hormone',
        'immune', 'antibody', 'antigen', 'vaccine', 'virus',
      ],
      'strongKeywords': [
        'cell', 'dna', 'rna', 'protein', 'gene', 'chromosome',
        'mitosis', 'meiosis', 'evolution', 'photosynthesis',
        'respiration', 'membrane', 'nucleus', 'bacteria',
        'enzyme', 'atp', 'metabolism', 'neuron', 'allele',
        'dominant', 'recessive', 'genotype', 'phenotype',
        'mutation', 'natural selection', 'adaptation',
        'chloroplast', 'mitochondria', 'ribosome',
      ],
      'patterns': [
        'genetics dna biology', 'cell biology',
        'photosynthesis biology', 'respiration biology',
        'evolution biology', 'protein biology', 'ecology biology',
      ],
      'antiKeywords': [
        'war', 'poem', 'novel', 'voltage', 'circuit', 'acid base',
      ],
    },

    // ── COMPUTER SCIENCE ────────────────────────────────────────
    'computer science': {
      'keywords': [
        'computer', 'software', 'hardware', 'program', 'code',
        'syntax', 'compile', 'debug', 'error', 'output',
        'input', 'variable', 'constant', 'type', 'integer',
        'string', 'boolean', 'float', 'array', 'list',
        'dictionary', 'tuple', 'set', 'null', 'pointer',
        'memory', 'stack', 'heap', 'cache', 'register',
        'cpu', 'ram', 'rom', 'storage', 'network',
        'protocol', 'server', 'client', 'database', 'query',
        'html', 'css', 'javascript', 'python', 'java',
      ],
      'strongKeywords': [
        'algorithm', 'function', 'class', 'object', 'loop',
        'recursion', 'binary', 'tree', 'graph', 'sorting',
        'searching', 'complexity', 'oop', 'inheritance',
        'polymorphism', 'encapsulation', 'abstraction',
        'linked list', 'data structure', 'operating system',
        'sql', 'api', 'framework', 'library', 'repository',
        'git', 'compiler', 'interpreter', 'runtime',
      ],
      'patterns': [
        'function programming', 'loop programming',
        'conditional programming', 'oop programming',
        'complexity algorithm', 'data structure', 'database sql',
      ],
      'antiKeywords': [
        'war', 'poem', 'cell', 'evolution', 'acid', 'force',
      ],
    },

    // ── HISTORY ─────────────────────────────────────────────────
    'history': {
      'keywords': [
        'ancient', 'medieval', 'modern', 'contemporary',
        'civilization', 'culture', 'society', 'government',
        'political', 'economic', 'social', 'military',
        'king', 'queen', 'emperor', 'ruler', 'dynasty',
        'election', 'democracy', 'republic', 'monarchy',
        'parliament', 'senate', 'constitution', 'law',
        'trade', 'silk', 'route', 'exploration', 'colonization',
        'slavery', 'abolition', 'rights', 'movement',
        'propaganda', 'nationalism', 'imperialism',
      ],
      'strongKeywords': [
        'war', 'revolution', 'empire', 'treaty', 'battle',
        'independence', 'colonial', 'conquest', 'invasion',
        'reform', 'renaissance', 'industrial', 'world war',
        'cold war', 'feudal', 'migration', 'century',
        'bc', 'ad', 'year', 'decade', 'era', 'period',
        'cause', 'effect', 'consequence', 'timeline',
        'primary source', 'secondary source', 'artifact',
      ],
      'patterns': [
        'year history', 'world war history',
        'revolution history', 'colonial history',
      ],
      'antiKeywords': [
        'cell', 'dna', 'equation', 'code', 'circuit',
      ],
    },

    // ── ENGLISH ─────────────────────────────────────────────────
    'english': {
      'keywords': [
        'read', 'write', 'speak', 'listen', 'comprehension',
        'passage', 'text', 'author', 'reader', 'audience',
        'fiction', 'nonfiction', 'genre', 'drama', 'tragedy',
        'comedy', 'sonnet', 'stanza', 'rhyme', 'rhythm',
        'alliteration', 'assonance', 'onomatopoeia', 'imagery',
        'symbolism', 'irony', 'sarcasm', 'tone', 'mood',
        'protagonist', 'antagonist', 'conflict', 'climax',
        'resolution', 'setting', 'narrative', 'dialogue',
        'essay', 'argument', 'evidence', 'conclusion',
      ],
      'strongKeywords': [
        'grammar', 'vocabulary', 'sentence', 'paragraph',
        'literature', 'novel', 'poem', 'metaphor', 'simile',
        'theme', 'character', 'plot', 'syntax', 'verb', 'noun',
        'adjective', 'adverb', 'tense', 'clause', 'punctuation',
        'shakespeare', 'prose', 'fiction', 'writing', 'language',
        'conjunction', 'preposition', 'pronoun', 'article',
        'passive', 'active', 'voice', 'direct', 'indirect',
      ],
      'patterns': [],
      'antiKeywords': [
        'cell', 'equation', 'force', 'reaction', 'war',
        'algorithm', 'circuit',
      ],
    },

    // ── GEOGRAPHY ───────────────────────────────────────────────
    'geography': {
      'keywords': [
        'continent', 'country', 'capital', 'border', 'region',
        'north', 'south', 'east', 'west', 'hemisphere',
        'mountain', 'river', 'ocean', 'sea', 'lake', 'valley',
        'plateau', 'desert', 'forest', 'grassland', 'tundra',
        'urban', 'rural', 'population', 'density', 'migration',
        'climate', 'weather', 'temperature', 'rainfall', 'wind',
        'natural', 'resource', 'environment', 'sustainable',
        'earthquake', 'volcano', 'tsunami', 'flood', 'drought',
      ],
      'strongKeywords': [
        'latitude', 'longitude', 'map', 'atlas', 'tectonic',
        'plate', 'biome', 'glacier', 'peninsula', 'island',
        'delta', 'estuary', 'canyon', 'erosion', 'deposition',
        'weathering', 'soil', 'water cycle', 'carbon cycle',
        'greenhouse', 'global warming', 'deforestation',
        'urbanization', 'gdp', 'developing', 'developed',
      ],
      'patterns': [],
      'antiKeywords': [
        'cell', 'equation', 'poem', 'algorithm', 'circuit',
      ],
    },

    // ── ECONOMICS ───────────────────────────────────────────────
    'economics': {
      'keywords': [
        'market', 'price', 'quantity', 'consumer', 'producer',
        'firm', 'industry', 'trade', 'import', 'export',
        'tariff', 'quota', 'subsidy', 'tax', 'revenue',
        'cost', 'profit', 'loss', 'investment', 'saving',
        'interest', 'rate', 'loan', 'debt', 'budget',
        'fiscal', 'monetary', 'policy', 'government', 'central',
        'bank', 'currency', 'exchange', 'growth', 'recession',
        'unemployment', 'wage', 'income', 'wealth', 'poverty',
      ],
      'strongKeywords': [
        'supply', 'demand', 'equilibrium', 'inflation',
        'deflation', 'gdp', 'gnp', 'macroeconomics',
        'microeconomics', 'elasticity', 'monopoly', 'oligopoly',
        'competition', 'opportunity cost', 'marginal',
        'utility', 'scarcity', 'allocation', 'efficiency',
      ],
      'patterns': [
        'supply demand economics', 'macroeconomics',
        'business economics',
      ],
      'antiKeywords': [
        'cell', 'equation', 'poem', 'algorithm', 'circuit',
        'evolution', 'force',
      ],
    },

    // ── ACCOUNTING ──────────────────────────────────────────────
    'accounting': {
      'keywords': [
        'account', 'journal', 'ledger', 'trial', 'balance',
        'asset', 'liability', 'equity', 'capital', 'owner',
        'transaction', 'entry', 'posting', 'closing',
        'depreciation', 'amortization', 'accrual', 'cash',
        'receivable', 'payable', 'inventory', 'stock',
        'dividend', 'retained', 'earnings', 'expense',
      ],
      'strongKeywords': [
        'debit', 'credit', 'balance sheet', 'income statement',
        'cash flow', 'profit loss', 'double entry',
        'financial statement', 'audit', 'gaap', 'ifrs',
        'gross profit', 'net profit', 'revenue', 'cost',
      ],
      'patterns': [
        'accounting',
      ],
      'antiKeywords': [
        'cell', 'equation', 'poem', 'algorithm', 'evolution',
        'force', 'circuit',
      ],
    },

    // ── PSYCHOLOGY ──────────────────────────────────────────────
    'psychology': {
      'keywords': [
        'mind', 'brain', 'mental', 'emotion', 'feeling',
        'thought', 'cognition', 'perception', 'attention',
        'memory', 'learning', 'motivation', 'attitude',
        'personality', 'intelligence', 'creativity',
        'stress', 'anxiety', 'depression', 'disorder',
        'therapy', 'treatment', 'counseling', 'clinical',
        'social', 'behavior', 'attitude', 'group', 'influence',
      ],
      'strongKeywords': [
        'psychology', 'psychologist', 'freud', 'piaget',
        'maslow', 'pavlov', 'conditioning', 'reinforcement',
        'behaviorism', 'cognitive', 'humanistic', 'psychoanalysis',
        'unconscious', 'subconscious', 'ego', 'id', 'superego',
        'stimulus', 'response', 'reflex', 'instinct', 'drive',
        'schema', 'hierarchy', 'needs', 'self-actualization',
      ],
      'patterns': [],
      'antiKeywords': [
        'cell', 'equation', 'circuit', 'reaction', 'force',
      ],
    },

    // ── ISLAMIAT ────────────────────────────────────────────────
    'islamiat': {
      'keywords': [
        'allah', 'prophet', 'islam', 'muslim', 'faith',
        'belief', 'prayer', 'fasting', 'zakat', 'hajj',
        'mosque', 'quran', 'hadith', 'sunnah', 'fiqh',
        'halal', 'haram', 'sin', 'reward', 'heaven', 'hell',
        'angel', 'revelation', 'worship', 'pillar',
        'muhammad', 'pbuh', 'sahaba', 'caliph', 'ummah',
      ],
      'strongKeywords': [
        'quran', 'hadith', 'sunnah', 'salah', 'sawm',
        'zakat', 'hajj', 'shahada', 'tawheed', 'aqeedah',
        'sharia', 'fatwa', 'ijtihad', 'ijma', 'qiyas',
        'ramadan', 'eid', 'masjid', 'imam', 'khutbah',
      ],
      'patterns': [
        'islamiat',
      ],
      'antiKeywords': [
        'cell', 'equation', 'circuit', 'algorithm', 'evolution',
      ],
    },

    // ── PAKISTAN STUDIES ────────────────────────────────────────
    'pakistan studies': {
      'keywords': [
        'pakistan', 'jinnah', 'quaid', 'lahore', 'karachi',
        'islamabad', 'punjab', 'sindh', 'balochistan', 'kpk',
        'partition', 'independence', 'british', 'india',
        'constitution', 'government', 'parliament', 'senate',
        'president', 'prime minister', 'federal', 'provincial',
        'indus', 'river', 'himalaya', 'karakoram', 'k2',
      ],
      'strongKeywords': [
        'pakistan movement', 'muslim league', 'allama iqbal',
        'liaquat ali', '1947', '1973 constitution',
        'two nation theory', 'cpec', 'gwadar',
        'kashmir', 'bengal', 'east pakistan', 'bangladesh',
      ],
      'patterns': [],
      'antiKeywords': [
        'cell', 'equation', 'circuit', 'algorithm',
      ],
    },

    // ── URDU ────────────────────────────────────────────────────
    'urdu': {
      'keywords': [
        'urdu', 'ghazal', 'nazm', 'shayari', 'adab',
        'iqbal', 'ghalib', 'faiz', 'mir', 'dastan',
        'mazmoon', 'inshaiya', 'qissa', 'kahani', 'drama',
        'lafz', 'maani', 'isteara', 'tashbih', 'kinaya',
      ],
      'strongKeywords': [
        'urdu literature', 'ghazal', 'nazm', 'qasida',
        'marsiya', 'masnavi', 'rubayi', 'hamd', 'naat',
      ],
      'patterns': [],
      'antiKeywords': [
        'cell', 'equation', 'circuit', 'algorithm', 'force',
      ],
    },
  };

  /// Classify OcrResult against user's subject list
  static ({String subject, double confidence}) classify(
    OcrResult ocrResult,
    List<String> userSubjects,
  ) {
    if (userSubjects.isEmpty || !ocrResult.hasEnoughText) {
      return (subject: 'Unclassified', confidence: 0.0);
    }

    final scores = <String, double>{};

    for (final userSubject in userSubjects) {
      final key = userSubject.toLowerCase().trim();

      // Find matching built-in subject
      final builtinKey = _findMatchingKey(key);
      if (builtinKey == null) {
        scores[userSubject] = 0.0;
        continue;
      }

      final data = _subjects[builtinKey]!;
      double score = 0.0;
      int totalPossible = 0;

      final combinedText = ocrResult.classifierInput.toLowerCase();
      final keywords = ocrResult.keywords
          .map((k) => k.toLowerCase())
          .toSet();
      final patterns = ocrResult.patterns
          .map((p) => p.toLowerCase())
          .toSet();

      // Score keywords (weight 1)
      for (final kw in data['keywords']!) {
        totalPossible += 1;
        if (combinedText.contains(kw) || keywords.contains(kw)) {
          score += 1.0;
        }
      }

      // Score strong keywords (weight 3)
      for (final kw in data['strongKeywords']!) {
        totalPossible += 3;
        if (combinedText.contains(kw) || keywords.contains(kw)) {
          score += 3.0;
        }
      }

      // Score patterns (weight 5)
      for (final pt in data['patterns']!) {
        totalPossible += 5;
        if (patterns.contains(pt) || combinedText.contains(pt)) {
          score += 5.0;
        }
      }

      // Anti-keyword penalty (-2 each)
      for (final anti in data['antiKeywords']!) {
        if (combinedText.contains(anti)) {
          score -= 2.0;
        }
      }

      // Normalize
      final normalized =
          totalPossible > 0 ? (score / totalPossible).clamp(0.0, 1.0) : 0.0;
      scores[userSubject] = normalized;
    }

    if (scores.isEmpty) {
      return (subject: 'Unclassified', confidence: 0.0);
    }

    final best =
        scores.entries.reduce((a, b) => a.value > b.value ? a : b);

    // Minimum threshold — if best score too low, unclassified
    if (best.value < 0.03) {
      return (subject: 'Unclassified', confidence: best.value);
    }

    return (subject: best.key, confidence: best.value);
  }

  static String? _findMatchingKey(String userSubject) {
    // Exact match first
    if (_subjects.containsKey(userSubject)) return userSubject;

    // Partial match
    for (final key in _subjects.keys) {
      if (key.contains(userSubject) ||
          userSubject.contains(key) ||
          _similarity(key, userSubject) > 0.7) {
        return key;
      }
    }
    return null;
  }

  // Simple similarity check for fuzzy matching subject names
  static double _similarity(String a, String b) {
    if (a == b) return 1.0;
    final shorter = a.length < b.length ? a : b;
    final longer = a.length < b.length ? b : a;
    if (longer.contains(shorter)) {
      return shorter.length / longer.length;
    }
    return 0.0;
  }

  /// Check if this subject is covered by built-in classifier
  static bool isKnownSubject(String subject) {
    return _findMatchingKey(subject.toLowerCase()) != null;
  }

  /// Get all built-in subject names
  static List<String> get knownSubjects => _subjects.keys.toList();
}