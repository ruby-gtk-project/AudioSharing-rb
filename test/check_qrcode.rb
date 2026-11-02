# frozen_string_literal: true

# Checks the QR encoder without a display: the symbol for an RTSP address,
# module for module, against test/qrcode_golden.txt — which is the matrix
# libqrencode produces for the same string at error correction level M in
# byte mode — plus the version boundaries and the structure every symbol has.
#
#   nix develop --command ruby test/check_qrcode.rb

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require 'qrcode'

ADDRESS = 'rtsp://192.168.1.5:8554/audio'
GOLDEN = File.readlines(File.expand_path('qrcode_golden.txt', __dir__), chomp: true).freeze
QUIET = QrCode::QUIET_ZONE

# The byte capacity of each version at level M: the last length that still
# fits before the encoder has to step up a version.
CAPACITIES = {
  1  => 14,
  2  => 26,
  3  => 42,
  4  => 62,
  5  => 84,
  6  => 106,
  7  => 122,
  8  => 152,
  9  => 180,
  10 => 213,
}.freeze

@failures = []

def check(description)
  if yield
    puts "  ok   #{description}"
  else
    puts "  FAIL #{description}"
    @failures << description
  end
rescue StandardError => e
  puts "  FAIL #{description} (#{e.class}: #{e.message})"
  @failures << description
end

def rows(content) = QrCode.new(content).items.map { |row| row.map { |dark| dark ? '1' : '0' }.join }

# The symbol itself, with the quiet zone stripped off again.
def symbol(content) = rows(content)[QUIET...-QUIET].map { |row| row[QUIET...-QUIET] }

puts 'the address encodes to the expected symbol'
check('the matrix matches the golden one') { rows(ADDRESS) == GOLDEN }
check('it is 29 modules across plus two quiet zones') { QrCode.new(ADDRESS).width == 29 + (QUIET * 2) }
check('it is square') { QrCode.new(ADDRESS).width == QrCode.new(ADDRESS).height }

def finder?(matrix, row, col)
  7.times.all? do |drow|
    7.times.all? do |dcol|
      distance = [(drow - 3).abs, (dcol - 3).abs].max
      matrix[row + drow][col + dcol] == (distance == 2 ? '0' : '1')
    end
  end
end

puts 'every symbol carries the function patterns'
['a', ADDRESS, 'x' * 200].each do |content|
  symbol(content).then do |matrix|
    size = matrix.size
    check("#{content.bytesize} bytes: the size is a legal one") { ((size - 17) % 4).zero? && size >= 21 }
    check("#{content.bytesize} bytes: three finder patterns") do
      [[0, 0], [0, size - 7], [size - 7, 0]].all? { |(row, col)| finder?(matrix, row, col) }
    end
    check("#{content.bytesize} bytes: the timing patterns alternate") do
      (8..size - 9).all? { |index| matrix[6][index] == (index.even? ? '1' : '0') }
    end
    check("#{content.bytesize} bytes: the dark module is dark") { matrix[size - 8][8] == '1' }
    check("#{content.bytesize} bytes: the quiet zone is empty") do
      rows(content).first(QUIET).all? { |row| row.count('1').zero? }
    end
  end
end

puts 'the version is the smallest the content fits in'
CAPACITIES.each do |version, capacity|
  check("#{capacity} bytes still fit in version #{version}") do
    QrCode.new('x' * capacity).width == 17 + (4 * version) + (QUIET * 2)
  end
end

check('content past the largest version is refused') do
  begin
    QrCode.new('x' * (CAPACITIES.fetch(10) + 1)).items
    false
  rescue ArgumentError
    true
  end
end

puts 'the empty code, which is what the picture shows before an address'
check('an empty string still encodes') { QrCode.new('').width == 21 + (QUIET * 2) }

puts
puts(@failures.empty? ? 'QRCODE OK' : "QRCODE FAILED (#{@failures.size})")
exit(@failures.empty? ? 0 : 1)
