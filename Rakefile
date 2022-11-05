task :default => :push


desc "ps"
task :ps do
     sh 'git ps origin master'
     sh 'git ps blog master'
end



desc "commit"
task :ci, :msg do |t, args|
     mm = args[:msg]
     sh "echo #{mm}"
end

desc "deploy"
task :d, :msg do |t, args|
      mm = args[:msg]
      sh "git add ."
      sh "git ci -am #{mm}"
      sh 'git ps origin master'
      sh 'git ps blog master'
end


