require 'spec_helper'

def create_test_object!
  allow(File).to receive(:writable?).with('repo') { true }
  allow(Git).to receive(:open).with('repo') { @git_double }
  allow(Git).to receive(:clone)
  allow(@git_double).to receive(:fetch)
  allow(@git_double).to receive(:checkout).with('master')
  allow(@git_double).to receive(:pull)
  allow(@git_double).to receive(:reset_hard)
  allow(@git_double).to receive(:dir) { './' }

  g = GitRepo.new 'git@git:some/repo.git', 'repo'
  expect(g.git).to eq(@git_double)
  g
end

describe 'GitRepo' do
  before :each do
    @git_double = double(:git_double)
    @git_repo = create_test_object!
  end
  describe 'initialize' do
    it 'should not clone repo if it exists' do
      expect(File).to receive(:writable?).with('repo') { true }
      expect(Git).to receive(:open).with('repo') { @git_double }
      expect(Git).not_to receive(:clone)
      expect(@git_double).to receive(:fetch)
      expect(@git_double).to receive(:checkout).with('master')
      expect(@git_double).to receive(:pull)
      expect(@git_double).to receive(:reset_hard)

      g = GitRepo.new 'git@git:some/repo.git', 'repo'
      expect(g.git).to eq(@git_double)
    end
    it 'should clone ssh repo if it does not exist' do
      expect(File).to receive(:writable?).with('repo') { false }
      expect(Git).to receive(:clone).with('git@git:some/repo.git', 'repo', {}) { @git_double }
      expect(Git).not_to receive(:open)
      expect(@git_double).to receive(:fetch)
      expect(@git_double).to receive(:checkout).with('master')
      expect(@git_double).to receive(:pull)
      expect(@git_double).to receive(:reset_hard)

      g = GitRepo.new 'git@git:some/repo.git', 'repo'
      expect(g.git).to eq(@git_double)
    end
    it 'should clone https repo if it does not exist' do
      expect(File).to receive(:writable?).with('repo') { false }
      expect(Git).to receive(:clone).with('git@git.com:vendor/repo.git', 'repo', {}) { @git_double }
      expect(Git).not_to receive(:open)
      expect(@git_double).to receive(:fetch)
      expect(@git_double).to receive(:checkout).with('master')
      expect(@git_double).to receive(:pull)
      expect(@git_double).to receive(:reset_hard)

      g = GitRepo.new 'https://git.com/vendor/repo.git', 'repo'
      expect(g.git).to eq(@git_double)
    end
  end

  describe 'delete_branch!' do
    it 'should not delete master' do
      expect { @git_repo.delete_branch! 'master' }.to raise_error ArgumentError, 'Can not remove branch master'
    end
    it 'should attempt to delete branch' do
      bd = double(:branch_double)
      expect(@git_double).to receive(:branch).with('some-branch') { bd }
      expect(bd).to receive(:delete)
      expect(@git_double).to receive(:chdir).and_yield
      expect(@git_repo).to receive(:`)
      @git_repo.delete_branch! 'some-branch'
    end
  end
  describe 'commits_between' do
    it 'should ask git.log about it' do
      expect(@git_double).to receive_message_chain(:log, :between).with('c1', 'c2')
      @git_repo.commits_between 'c1', 'c2'
    end
  end
  describe 'checkout' do
    it 'should just checkout commit if no block given' do
      expect(@git_double).to receive(:revparse).with('HEAD') { 'c321' }
      expect(@git_double).to receive(:checkout).with('c123')
      @git_repo.checkout 'c123'
    end
    it 'should checkout, call a block and checkout prev commit if block given' do
      expect(@git_double).to receive(:revparse).with('HEAD') { 'c321' }
      expect(@git_double).to receive(:checkout).with('c123')
      expect(@git_double).to receive(:checkout).with('c321')
      a = 1
      @git_repo.checkout 'c123' do
        a = 2
      end
      expect(a).to eq 2
    end
    it 'should do nothing if commit ommited' do
      expect(@git_double).not_to receive(:revparse)
      expect(@git_double).not_to receive(:checkout)
      @git_repo.checkout
      a = 1
      @git_repo.checkout do
        a = 2
      end
      expect(a).to eq 2
    end
  end
  describe 'current commit' do
    it 'should ask revparse' do
      expect(@git_double).to receive(:revparse).with('HEAD') { 'hash' }
      expect(@git_repo.current_commit).to eq('hash')
    end
  end
  describe 'has_jscs, has_jshint' do
    it 'should not run any commands if flags are dropped' do
      expect(@git_repo).to receive(:has_jscs?) { false }
      expect(@git_repo).to receive(:has_jshint?) { false }
      expect(@git_repo).not_to receive(:run_command)
      @git_repo.check_jscs 'some/file.js'
      @git_repo.check_jshint 'some/file.js'
    end
    it 'should run commands if flags are not dropped' do
      expect(@git_repo).to receive(:has_jscs?).ordered { true }
      expect(@git_repo).to receive(:run_check)
        .with('jscs -c \'.//.jscsrc\' -r inline .//some/file.js', 'some/file.js', [])
        .ordered { '' }
      expect(@git_repo).to receive(:has_jshint?).ordered { true }
      expect(@git_repo).to receive(:run_check)
        .with('jshint -c \'.//.jshintrc\' .//some/file.js', 'some/file.js', [])
        .ordered { '' }
      @git_repo.check_jscs 'some/file.js'
      @git_repo.check_jshint 'some/file.js'
    end
  end
  describe 'has_jscs? has_jshint?' do
    it 'should check only once and answer false' do
      expect(File).to receive(:readable?).with('.//.jscsrc').once { false }
      expect(File).to receive(:readable?).with('.//.jshintrc').once { false }
      expect(@git_repo).not_to have_jscs
      expect(@git_repo).not_to have_jscs
      expect(@git_repo).not_to have_jshint
      expect(@git_repo).not_to have_jshint
    end
    it 'should answer true' do
      expect(File).to receive(:readable?).with('.//.jscsrc').once { true }
      expect(File).to receive(:readable?).with('.//.jshintrc').once { true }
      expect(@git_repo).to have_jscs
      expect(@git_repo).to have_jshint
    end
  end
  describe 'format line' do
    it 'should skip lines' do
      text = ['some line',
              'some else line',
              'file.js: line 10,20: some fail',
              '']
      result = ''
      text.each do |line|
        formatted = @git_repo.send(:format_line, line, [0..10])
        result << formatted if formatted
      end
      expect(result).to eq "10,20: some fail\n"
    end
    it 'should skip lines if numbers are not in range' do
      text = ['some line',
              'file.js: line 10,20: some fail',
              'file.js: line 30,20: some else fail',
              '']
      result = ''
      text.each do |line|
        formatted = @git_repo.send(:format_line, line, [0..10])
        result << formatted if formatted
      end
      expect(result).to eq "10,20: some fail\n"
    end
    it 'should format lines' do
      text = ['file.js: line 10,20: some fail',
              'file.js: line 30,20: some else fail',
              'file.js: line 40,20: some more fail']
      result = ''
      text.each do |line|
        formatted = @git_repo.send(:format_line, line, [0..10, 35..42])
        result << formatted if formatted
      end
      expect(result).to eq "10,20: some fail\n40,20: some more fail\n"
    end
  end
  describe 'diffed_lines' do
    it 'should parse diff' do
      # rubocop:disable Metrics/LineLength
      diff = "diff --git a/src/tw_shared_types/DAL/buyermanager/riak.js b/src/tw_shared_types/DAL/buyermanager/riak.js
index 7b85bc4..c8d6996 100644
--- a/src/tw_shared_types/DAL/buyermanager/riak.js
+++ b/src/tw_shared_types/DAL/buyermanager/riak.js
@@ -710,6 +710,12 @@ exports.saveBuyerInformation = function(buyer, callback){

                                                for(var j = 0; j < newdata.passengers.length; j++){
                                                        if(newdata.passengers[j].passNumber == buyer.passengers[i].passNumber){
+                                                               if(buyer.passengers[i].middleName != null){
+                                                                       if(buyer.passengers[i].middleName.trim() != '' && buyer.passengers[i].middleName != buyer.passengers[i].middleName){
+                                                                               // если для существующего пассажира изменилось отчество, обновляем
+                                                                               newdata.passengers[j].middleName = buyer.passengers[i].middleName;
+                                                                       }
+                                                               }
                                                                found = true;
                                                                break;
                                                        }
@@ -718,18 +724,13 @@ exports.saveBuyerInformation = function(buyer, callback){
                                                // Add frequentFlyerCard if necessary
                                                var curPas = JSON.parse(JSON.stringify(buyer.passengers[i]));

-                                               // на этом этапе имена уже могут быть урезанные для работы с ГДС, а нам в записной книжке нужны нормльные имена
-                                               if(curPas.origFirstName){
-                                                       curPas.firstName = curPas.origFirstName;
-                                                       delete curPas.origFirstName;
+                                               // на этом этапе имена уже могут быть урезанные для работы с ГДС, поэтому убираем их для записной книги
+                                               if(curPas.gdsFirstName){
+                                                       delete curPas.gdsFirstName;
                                                }
-                                               if(curPas.middleName && !curPas.middleName.trim()){
-                                                       curPas.firstName += ' ' + curPas.middleName;
-                                               }
-                                               delete curPas.middleName;
-                                               if(curPas.origLastName){
-                                                       curPas.lastName = curPas.origLastName;
-                                                       delete curPas.origLastName;
+
+                                               if(curPas.gdsLastName){
+                                                       delete curPas.gdsLastName;
                                                }

                                                if(curPas.frequentFlyerCard){
"
      # rubocop:enable Metrics/LineLength
      res = @git_repo.send :diffed_lines, diff
      expect(res).to eq [710..722, 724..737]
    end
    it 'should return some result if diff is empty' do
      diff = ''
      res = @git_repo.send :diffed_lines, diff
      expect(res).to eq []
    end
    it 'should not raise error if diff contains no "diff" line marks' do
      # rubocop:disable Metrics/LineLength
      diff = "diff --git a/src/tw_shared_types/DAL/buyermanager/riak.js b/src/tw_shared_types/DAL/buyermanager/riak.js
index 7b85bc4..c8d6996 100644
--- a/src/tw_shared_types/DAL/buyermanager/riak.js
+++ b/src/tw_shared_types/DAL/buyermanager/riak.js


                                                for(var j = 0; j < newdata.passengers.length; j++){
                                                        if(newdata.passengers[j].passNumber == buyer.passengers[i].passNumber){
+                                                               if(buyer.passengers[i].middleName != null){
+                                                                       if(buyer.passengers[i].middleName.trim() != '' && buyer.passengers[i].middleName != buyer.passengers[i].middleName){
+                                                                               // если для существующего пассажира изменилось отчество, обновляем
+                                                                               newdata.passengers[j].middleName = buyer.passengers[i].middleName;
+                                                                       }
+                                                               }
                                                                found = true;
                                                                break;
                                                        }

                                                // Add frequentFlyerCard if necessary
                                                var curPas = JSON.parse(JSON.stringify(buyer.passengers[i]));

-                                               // на этом этапе имена уже могут быть урезанные для работы с ГДС, а нам в записной книжке нужны нормльные имена
-                                               if(curPas.origFirstName){
-                                                       curPas.firstName = curPas.origFirstName;
-                                                       delete curPas.origFirstName;
+                                               // на этом этапе имена уже могут быть урезанные для работы с ГДС, поэтому убираем их для записной книги
+                                               if(curPas.gdsFirstName){
+                                                       delete curPas.gdsFirstName;
                                                }
-                                               if(curPas.middleName && !curPas.middleName.trim()){
-                                                       curPas.firstName += ' ' + curPas.middleName;
-                                               }
-                                               delete curPas.middleName;
-                                               if(curPas.origLastName){
-                                                       curPas.lastName = curPas.origLastName;
-                                                       delete curPas.origLastName;
+
+                                               if(curPas.gdsLastName){
+                                                       delete curPas.gdsLastName;
                                                }

                                                if(curPas.frequentFlyerCard){
"
      # rubocop:enable Metrics/LineLength
      expect(@git_repo).to receive(:puts).twice
      expect do
        @git_repo.send :diffed_lines, diff
      end.not_to raise_error
    end
  end

  describe 'run command' do
    let(:text) { "line1\nline2\nline3" }
    it 'should run commands' do
      expect(Open3).to receive(:capture2e).with('cmd') { ['', nil] }
      @git_repo.send :run_command, 'cmd'
    end
    it 'should run commands within commit if specified' do
      expect(@git_repo).to receive(:checkout).with('commit').and_yield @git_repo
      expect(Open3).to receive(:capture2e).with('cmd') { ['', nil] }
      @git_repo.send :run_command, 'cmd', 'commit'
    end
    it 'should yield each line if block given' do
      expect(Open3).to receive(:capture2e).with('cmd') { [text, nil] }
      f = double(:fake)
      expect(f).to receive(:some_method).with(instance_of(String)).exactly(3).times
      @git_repo.send :run_command, 'cmd' do |line|
        f.some_method line
      end
    end
    it 'should return whole output if block given' do
      expect(Open3).to receive(:capture2e).with('cmd') { [text, nil] }
      expect(@git_repo.send(:run_command, 'cmd')).to eq [text, nil]
    end
    it 'should fail on empty command (?)' do
      expect do
        @git_repo.send :run_command, ''
      end.to raise_error ArgumentError, 'Empty or nil command!'
    end
  end
end
