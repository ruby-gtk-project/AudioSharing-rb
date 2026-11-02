# frozen_string_literal: true

# QrCode encodes a string as the module matrix of a QR code.
#
# Ported from upstream's src/qrcode.rs, a GObject wrapper around the Rust
# `qrcode` crate: it encodes the content bytes at error correction level M and
# renders them with a four module quiet zone, exposing the result as `items`
# (rows of booleans, true where the module is dark) plus its `width` and
# `height`.
#
# No gem in this port's bundle encodes QR codes, so the encoder is here:
# a byte mode segment, Reed-Solomon error correction, module placement and
# mask selection as specified by ISO/IEC 18004. Versions 1 to 10 are covered,
# which at level M holds 213 bytes — an RTSP address is thirty.
class QrCode
  # The light border the matrix is rendered with, in modules. The crate's
  # `quiet_zone(true)` is this.
  QUIET_ZONE = 4

  # The byte mode indicator, the only segment mode this encoder emits.
  BYTE_MODE = 4

  # The two bit indicator of error correction level M.
  EC_LEVEL_BITS = 0b00

  # Per version, at level M: total codewords, error correction codewords per
  # block, and the number of blocks. Every other figure — data capacity, the
  # short and long block lengths — follows from these three.
  VERSIONS = {
    1  => [26, 10, 1],
    2  => [44, 16, 1],
    3  => [70, 26, 1],
    4  => [100, 18, 2],
    5  => [134, 24, 2],
    6  => [172, 16, 4],
    7  => [196, 18, 4],
    8  => [242, 22, 4],
    9  => [292, 22, 5],
    10 => [346, 26, 5],
  }.freeze

  # Row and column centres of the alignment patterns, per version.
  ALIGNMENT_CENTRES = {
    1  => [],
    2  => [6, 18],
    3  => [6, 22],
    4  => [6, 26],
    5  => [6, 30],
    6  => [6, 34],
    7  => [6, 22, 38],
    8  => [6, 24, 42],
    9  => [6, 26, 46],
    10 => [6, 28, 50],
  }.freeze

  # The padding codewords that fill a message out to the version's capacity.
  PAD_BYTES = [0xEC, 0x11].freeze

  # The field polynomial of GF(256), and the generators of the two BCH codes
  # that protect the format and version information.
  GF_POLYNOMIAL = 0x11D
  FORMAT_GENERATOR = 0x537
  FORMAT_MASK = 0x5412
  VERSION_GENERATOR = 0x1F25

  # The weights of the four mask penalty rules.
  PENALTY_RUN = 3
  PENALTY_BOX = 3
  PENALTY_FINDER = 40
  PENALTY_BALANCE = 10

  attr_reader :content

  def initialize(content)
    @content = content.to_s
  end

  # The module matrix with its quiet zone, as rows of booleans.
  def items = @items ||= with_quiet_zone(matrix)

  def width = items.first.size
  def height = items.size

  private

    # --- The matrix -----------------------------------------------------

    # The masked matrix, with the mask the four penalty rules prefer. Ties go
    # to the lower mask number, which is what `min_by` keeps.
    def matrix = @matrix ||= (0..7).map { |mask| masked(mask) }.min_by { |candidate| penalty(candidate) }

    # The matrix before masking: function patterns, then the codewords. The
    # rows being written are held in @target, so the methods below take a
    # position and a colour and nothing else.
    def grid
      @grid ||= Array.new(size) { Array.new(size, false) }.tap do |rows|
        @target = rows
        place_timing
        place_finders
        place_alignment
        write_version
        write_format(0)
        place_codewords
      end
    end

    # A copy of the grid with one mask applied. The mask covers the data
    # modules only, so the format information is written afterwards.
    def masked(mask)
      grid.map(&:dup).tap do |candidate|
        size.times do |row|
          size.times do |col|
            if !function?(row, col) && mask?(mask, row, col)
              candidate[row][col] = !candidate[row][col]
            end
          end
        end
        @target = candidate
        write_format(mask)
      end
    end

    def with_quiet_zone(rows)
      border = Array.new(QUIET_ZONE, false)
      blank = Array.new(QUIET_ZONE) { Array.new(rows.first.size + (QUIET_ZONE * 2), false) }
      blank + rows.map { |row| border + row + border } + blank
    end

    def size = @size ||= 17 + (4 * version)

    # --- Function patterns ----------------------------------------------

    # The three finder patterns, each drawn with its separator: inside the nine
    # by nine area around the centre, the rings two and four steps out from it
    # are light and everything else is dark.
    def place_finders
      [[3, 3], [3, size - 4], [size - 4, 3]].each do |centre|
        (-4..4).each do |drow|
          (-4..4).each { |dcol| place_finder_module(centre, drow, dcol) }
        end
      end
    end

    def place_finder_module(centre, drow, dcol)
      row = centre.first + drow
      col = centre.last + dcol
      distance = [drow.abs, dcol.abs].max
      if inside?(row, col)
        set_function(row, col, distance != 2 && distance != 4)
      end
    end

    def place_timing
      size.times do |index|
        set_function(6, index, index.even?)
        set_function(index, 6, index.even?)
      end
    end

    # The alignment patterns sit at every pair of centres except the three
    # that would land on a finder pattern.
    def place_alignment
      ALIGNMENT_CENTRES.fetch(version).then do |centres|
        centres.each_with_index do |row, i|
          centres.each_with_index do |col, j|
            unless finder_corner?(i, j, centres.size)
              place_alignment_pattern(row, col)
            end
          end
        end
      end
    end

    def place_alignment_pattern(row, col)
      (-2..2).each do |drow|
        (-2..2).each do |dcol|
          set_function(row + drow, col + dcol, [drow.abs, dcol.abs].max != 1)
        end
      end
    end

    def finder_corner?(i, j, count)
      last = count - 1
      (i.zero? && j.zero?) || (i.zero? && j == last) || (i == last && j.zero?)
    end

    # Both copies of the fifteen bit format information, and the module next
    # to the lower left finder that is always dark.
    def write_format(mask)
      format_bits(mask).then do |bits|
        (0..5).each { |i| set_function(i, 8, bit?(bits, i)) }
        set_function(7, 8, bit?(bits, 6))
        set_function(8, 8, bit?(bits, 7))
        set_function(8, 7, bit?(bits, 8))
        (9..14).each { |i| set_function(8, 14 - i, bit?(bits, i)) }
        (0..7).each { |i| set_function(8, size - 1 - i, bit?(bits, i)) }
        (8..14).each { |i| set_function(size - 15 + i, 8, bit?(bits, i)) }
        set_function(size - 8, 8, true)
      end
    end

    # Both copies of the eighteen bit version information, which versions
    # below 7 do not carry.
    def write_version
      if version >= 7
        version_bits.then do |bits|
          18.times do |i|
            far = size - 11 + (i % 3)
            near = i / 3
            set_function(near, far, bit?(bits, i))
            set_function(far, near, bit?(bits, i))
          end
        end
      end
    end

    def format_bits(mask)
      ((EC_LEVEL_BITS << 3) | mask).then do |data|
        ((data << 10) | bch(data, 10, FORMAT_GENERATOR)) ^ FORMAT_MASK
      end
    end

    def version_bits = (version << 12) | bch(version, 12, VERSION_GENERATOR)

    # The remainder of the data shifted up by `steps`, divided by the
    # generator polynomial over GF(2).
    def bch(data, steps, generator)
      steps.times.inject(data) { |remainder, _| (remainder << 1) ^ (((remainder >> (steps - 1)) & 1) * generator) }
    end

    # --- Data placement -------------------------------------------------

    # The codewords walk up and down two module wide columns from the right
    # edge, stepping over the function modules and over the vertical timing
    # pattern in column 6. Modules past the last codeword are the remainder
    # bits, which stay light.
    def place_codewords
      bits = codeword_bits
      placed = 0
      right = size - 1
      while right >= 1
        if right == 6
          right = 5
        end
        size.times do |step|
          2.times do |offset|
            row = codeword_row(right, step)
            col = right - offset
            if !function?(row, col) && placed < bits.size
              @target[row][col] = bits[placed]
              placed += 1
            end
          end
        end
        right -= 2
      end
    end

    # Every second column pair is walked upwards.
    def codeword_row(right, step)
      if ((right + 1) & 2).zero?
        size - 1 - step
      else
        step
      end
    end

    def codeword_bits = codewords.flat_map { |byte| 7.downto(0).map { |index| bit?(byte, index) } }

    # The codewords of every block, interleaved. The short blocks are one
    # codeword shorter than the long ones, so the slot where a short block has
    # no data codeword is skipped.
    def codewords
      blocks.then do |grouped|
        [].tap do |interleaved|
          grouped.first.size.times do |index|
            grouped.each_with_index do |block, position|
              if index != short_data_length || position >= short_block_count
                interleaved << block[index]
              end
            end
          end
        end
      end
    end

    # Each block, its data codewords followed by its error correction
    # codewords, padded to the length of a long block so the interleaving can
    # walk them in step.
    def blocks
      divisor = rs_divisor(ec_codewords)
      offset = 0
      Array.new(block_count) do |index|
        length = short_data_length
        if index >= short_block_count
          length += 1
        end
        data = data_codewords[offset, length]
        offset += length
        block_of(data, divisor)
      end
    end

    def block_of(data, divisor)
      filler = Array.new(short_block_length + 1 - data.size - ec_codewords, 0)
      data + filler + rs_remainder(data, divisor)
    end

    # --- Codewords ------------------------------------------------------

    # The message: the mode indicator, the byte count, the content, the
    # terminator, and the pad codewords that fill the version's capacity.
    def data_codewords
      @data_codewords ||= message_bits.each_slice(8).map { |slice| byte_of(slice) }.then do |words|
        words + Array.new(data_capacity - words.size) { |index| PAD_BYTES[index % 2] }
      end
    end

    def message_bits
      [].tap do |bits|
        append_bits(bits, BYTE_MODE, 4)
        append_bits(bits, bytes.bytesize, count_bits)
        bytes.each_byte { |byte| append_bits(bits, byte, 8) }
        [4, (data_capacity * 8) - bits.size].min.times { bits << false }
        ((8 - (bits.size % 8)) % 8).times { bits << false }
      end
    end

    def append_bits(bits, value, count)
      (count - 1).downto(0) { |index| bits << bit?(value, index) }
    end

    def byte_of(slice) = slice.inject(0) { |byte, bit| (byte << 1) | bit_value(bit) }

    def bytes = @bytes ||= content.b

    # The smallest version the content fits in.
    def version
      @version ||= VERSIONS.keys.sort.find { |candidate| byte_capacity(candidate) >= bytes.bytesize } ||
        raise(ArgumentError, "#{bytes.bytesize} bytes exceeds the #{byte_capacity(VERSIONS.keys.max)} a QR code of version #{VERSIONS.keys.max} holds")
    end

    # How many content bytes a version holds: its data codewords, less the
    # mode indicator and the byte count.
    def byte_capacity(candidate)
      ((data_capacity_of(candidate) * 8) - 4 - count_bits_of(candidate)) / 8
    end

    def total_codewords = VERSIONS.fetch(version).first
    def ec_codewords = VERSIONS.fetch(version)[1]
    def block_count = VERSIONS.fetch(version).last
    def data_capacity = data_capacity_of(version)

    def data_capacity_of(candidate)
      total, ec, blocks = VERSIONS.fetch(candidate)
      total - (ec * blocks)
    end

    # The byte count field is eight bits wide up to version 9 and sixteen from
    # version 10 on.
    def count_bits = count_bits_of(version)

    def count_bits_of(candidate)
      if candidate <= 9
        8
      else
        16
      end
    end

    def short_block_length = total_codewords / block_count
    def short_data_length = short_block_length - ec_codewords
    def short_block_count = block_count - (total_codewords % block_count)

    # --- Reed-Solomon ---------------------------------------------------

    # The generator polynomial of a code with the given number of error
    # correction codewords, as the coefficients below its leading term.
    def rs_divisor(degree)
      Array.new(degree, 0).tap do |result|
        result[degree - 1] = 1
        root = 1
        degree.times do
          result.each_index do |index|
            result[index] = gf_multiply(result[index], root)
            if index + 1 < degree
              result[index] ^= result[index + 1]
            end
          end
          root = gf_multiply(root, 0x02)
        end
      end
    end

    def rs_remainder(data, divisor)
      Array.new(divisor.size, 0).tap do |result|
        data.each do |byte|
          factor = byte ^ result.shift
          result << 0
          result.each_index { |index| result[index] ^= gf_multiply(divisor[index], factor) }
        end
      end
    end

    # Multiplication in GF(256), reducing by the field polynomial as it goes.
    def gf_multiply(left, right)
      product = 0
      7.downto(0) do |index|
        product = (product << 1) ^ ((product >> 7) * GF_POLYNOMIAL)
        product ^= ((right >> index) & 1) * left
      end
      product & 0xFF
    end

    # --- Masking --------------------------------------------------------

    def mask?(pattern, row, col)
      case pattern
      when 0 then ((row + col) % 2).zero?
      when 1 then (row % 2).zero?
      when 2 then (col % 3).zero?
      when 3 then ((row + col) % 3).zero?
      when 4 then (((col / 3) + (row / 2)) % 2).zero?
      when 5 then (((col * row) % 2) + ((col * row) % 3)).zero?
      when 6 then ((((col * row) % 2) + ((col * row) % 3)) % 2).zero?
      when 7 then ((((col + row) % 2) + ((col * row) % 3)) % 2).zero?
      end
    end

    # The four penalty rules: runs of five or more, two by two blocks of one
    # colour, finder lookalikes, and an unbalanced ratio of dark to light.
    def penalty(candidate)
      line_penalty(candidate) + line_penalty(candidate.transpose) +
        box_penalty(candidate) + balance_penalty(candidate)
    end

    def line_penalty(lines)
      lines.sum { |line| runs_of(line).then { |runs| run_penalty(runs) + finder_penalty(runs) } }
    end

    # A line as the lengths of its runs of one colour. A line that starts dark
    # gets the quiet zone in front of it as a run of -1, so that a dark run
    # always sits at an odd index — the convention libqrencode's
    # Mask_calcRunLengthH sets up and its two rules below rely on.
    def runs_of(line)
      [].tap do |runs|
        if line.first
          runs << -1
        end
        line.each_with_index do |value, index|
          if index.positive? && line[index - 1] == value
            runs[-1] += 1
          else
            runs << 1
          end
        end
      end
    end

    # Runs of five modules or more, the sixth and each one after it counting
    # one more than the five before them.
    def run_penalty(runs) = runs.sum { |length| run_score(length) }

    def run_score(length)
      if length >= 5
        PENALTY_RUN + length - 5
      else
        0
      end
    end

    # The finder pattern's 1:1:3:1:1 ratio, at any scale, with four units of
    # light on one side of it. The run before the first and after the last are
    # the quiet zone, which counts as light.
    def finder_penalty(runs)
      (0...runs.size).sum { |index| finder_run_score(runs, index) }
    end

    def finder_run_score(runs, index)
      if finder_centre?(runs, index) && finder_ratio?(runs, index)
        PENALTY_FINDER
      else
        0
      end
    end

    def finder_centre?(runs, index)
      index.odd? && index >= 3 && index < runs.size - 2 && (runs[index] % 3).zero?
    end

    def finder_ratio?(runs, index)
      unit = runs[index] / 3
      finder_core?(runs, index, unit) && finder_light_side?(runs, index, unit)
    end

    def finder_core?(runs, index, unit)
      [index - 2, index - 1, index + 1, index + 2].all? { |position| runs[position] == unit }
    end

    def finder_light_side?(runs, index, unit)
      index == 3 || runs[index - 3] >= 4 * unit ||
        index + 4 >= runs.size || runs[index + 3] >= 4 * unit
    end

    def box_penalty(candidate)
      (0...size - 1).sum do |row|
        (0...size - 1).count do |col|
          candidate[row][col].then do |value|
            value == candidate[row][col + 1] && value == candidate[row + 1][col] && value == candidate[row + 1][col + 1]
          end
        end * PENALTY_BOX
      end
    end

    # Every five per cent the proportion of dark modules strays from half,
    # the proportion rounded to the nearest per cent.
    def balance_penalty(candidate)
      total = size * size
      candidate.sum { |row| row.count(true) }.then do |dark|
        ((((200 * dark) + total) / total / 2) - 50).abs / 5 * PENALTY_BALANCE
      end
    end

    # --- Grid helpers ---------------------------------------------------

    def function_grid = @function_grid ||= Array.new(size) { Array.new(size, false) }
    def function?(row, col) = function_grid[row][col]
    def inside?(row, col) = row.between?(0, size - 1) && col.between?(0, size - 1)

    def set_function(row, col, dark)
      @target[row][col] = dark
      function_grid[row][col] = true
    end

    def bit?(value, index) = ((value >> index) & 1) == 1

    def bit_value(bit)
      if bit
        1
      else
        0
      end
    end
end
